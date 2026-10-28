extends SceneTree

var checks = 0
var failures: Array = []
var report = {}
var folder = OS.get_environment("PVE_CONTENT_QA_DIR")

func _initialize():
	call_deferred("execute")

func check(condition: bool, message: String):
	checks += 1
	if not condition: failures.append(message)

func execute():
	if folder.is_empty(): folder = OS.get_user_data_dir().path_join("content_validation_tests")
	DirAccess.make_dir_recursive_absolute(folder)
	var db = load("res://PvE/Rules/content/ContentDB.gd").new()
	check(db.errors.is_empty(), "缓存正常载入")
	check(db.content_version == "0.1.3", "内容版本0.1.3")
	check(db.table_names().size() == 57, "全部56内容表及清单")
	check(db.value("grid_width") is int and db.value("grid_width") == 9, "原生整数类型保留")
	check(db.get_row("shop_rarity_curve", "act_1").common_weight == 0.8, "章节主键查找")
	check(db.get_row("enemy_build_items", "rust_scout_a|rust_scout_a_item_1").item_id == "utility_knife", "复合主键查找")
	check(db.parse_params("value:poison:2|duration:3|negative:-0.2|enabled:true") == {"value": "poison:2", "duration": 3, "negative": -0.2, "enabled": true}, "参数首冒号与标量类型")
	var original = {"value": {"nested": [1, 2]}}
	var copy = db.parse_params(original)
	copy.value.nested.append(3)
	check(original.value.nested == [1, 2], "参数字典深复制")
	var rows = db.rows("items"); var first_id = str(rows[0].id); var price = rows[0].base_price
	rows[0].base_price = 999
	check(db.get_row("items", first_id).base_price == price, "行数组查询不可改数据库")
	var row = db.get_row("items", first_id); row.tags = "changed"
	check(db.get_row("items", first_id).tags != "changed", "单行查询不可改数据库")
	check(db.text("item.utility_knife.name", "zh_CN") != db.text("item.utility_knife.name", "en"), "中英文独立文本")
	check(db.text("tag.burst.name", "zh_CN") == "爆发", "情报词汇有中文")
	check(db.shape("shape_1") == [Vector2i(0,0)], "形状输出Vector2i")
	check(db.boss_bags("boss_iron_beast").size() == 6, "Boss使用显式六个背包")
	var tables = ["items", "bags", "recipes", "characters", "encounter_templates", "enemy_builds", "events", "reward_tables", "difficulty_levels", "statuses"]
	for table in tables:
		var definition_row = db.rows(table)[0]
		var definition = db.get_definition(table, str(definition_row.id))
		check(definition is Resource, table + "原生Resource")
		check(definition.data == definition_row, table + "定义数据完整")
		var properties = {}
		for property in definition.get_property_list(): properties[property.name] = true
		for key in definition_row:
			if properties.has(key): check(definition.get(key) == definition_row[key], table + "." + key + " typed getter matches schema")
		var copied = definition.data; copied["_extra"] = [1, {"test": true}]
		check(not definition.data.has("_extra"), table + "readonly copy")
		# Payload contains nested dictionaries/arrays, so this checks serialization beyond simple IDs.
		var roundtrip = definition.get_script().new(copied)
		var first = folder.path_join(table + "-first.tres")
		var second = folder.path_join(table + "-second.tres")
		check(ResourceSaver.save(roundtrip, first) == OK, table + "first save")
		var reopened = ResourceLoader.load(first, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(reopened != null and reopened.data == copied, table + "first reopen keeps full data")
		check(ResourceSaver.save(reopened, second) == OK, table + "second save")
		var reopened_twice = ResourceLoader.load(second, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(reopened_twice != null and reopened_twice.data == copied, table + "second reopen keeps full data")
	var validator = load("res://PvE/Rules/content/ContentValidator.gd").new(db)
	var valid = validator.validate()
	check(valid.ok, "原生内容校验零错误：" + str(valid.errors))
	check(valid.counts.native_layouts == 40, "全部40起始/敌人/Boss两阶段布局复验")
	check(valid.counts.content_pool_checks >= 80, "奖励事件每角色每章节池验证")
	for definition in db.rows("items") + db.rows("bags"):
		var image = ResourceLoader.load(str(definition.icon_ref))
		check(image is Texture2D and image.get_width() > 0 and image.get_height() > 0, "原PNG纹理资源可载入 " + str(definition.id))
	check(valid.route_battle_range == {"min": 12.0, "max": 15.0}, "可达战斗数12至15")
	var corrupt = JSON.parse_string(FileAccess.get_file_as_string("res://PvE/Rules/content/compiled/content.json"))
	corrupt.tables.starting_build_items[0].origin_x = 99
	var broken_path = folder.path_join("invalid_geometry.json")
	var file = FileAccess.open(broken_path, FileAccess.WRITE);file.store_string(JSON.stringify(corrupt));file.close()
	var broken = load("res://PvE/Rules/content/ContentDB.gd").new(broken_path)
	var failed = validator.validate(broken)
	check(not failed.ok and failed.errors.any(func(message): return "画布" in message), "损坏缓存布局能报告中文越界")
	var missing = load("res://PvE/Rules/content/ContentDB.gd").new(folder.path_join("not-present.json"))
	check(not missing.errors.is_empty(), "缺少缓存有明确错误")
	var damaged_path = folder.path_join("invalid_structure.json")
	file = FileAccess.open(damaged_path, FileAccess.WRITE); file.store_string('{"format":"backpack-pve-content","schema_version":1,"tables":"broken"}'); file.close()
	var damaged = load("res://PvE/Rules/content/ContentDB.gd").new(damaged_path)
	check(not damaged.errors.is_empty() and damaged.errors[0].contains("已损坏"), "损坏缓存结构有中文错误而非脚本异常")
	report = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "content_sha256": db.content_sha256,
		"content_version": db.content_version, "native_validation": valid, "definition_resource_types": tables.size(), "resource_roundtrip_loads": 20}
	var report_path = OS.get_environment("PVE_CONTENT_QA_REPORT")
	if report_path.is_empty(): report_path = folder.path_join("content_native_tests.json")
	var output = FileAccess.open(report_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"));output.close()
	print(JSON.stringify({"ok": report.ok, "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
