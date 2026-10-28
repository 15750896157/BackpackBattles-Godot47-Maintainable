class_name ContentValidator
extends RefCounted

var db
var _errors: Array = []
var _warnings: Array = []
var _layouts: int = 0

func _init(content = null):
	db = content

func validate(content = null) -> Dictionary:
	if content != null: db = content
	_errors.clear(); _warnings.clear(); _layouts = 0
	if db == null: return {"ok": false, "error": "未提供内容数据库", "errors": ["未提供内容数据库"], "warnings": [], "counts": {}}
	_errors.append_array(db.errors)
	var imported = db.validation_info()
	if imported.is_empty(): _errors.append("缓存缺少完整配置审计；请重新导入CSV")
	_errors.append_array(imported.get("errors", []))
	_warnings.append_array(imported.get("warnings", []))
	if db.table_names().size() != 57: _errors.append("配置应有56张内容表及清单")
	var schema = JSON.parse_string(FileAccess.get_file_as_string("res://PvE/Rules/content/schema.json"))
	if not schema is Dictionary:
		_errors.append("缺少冻结字段与引用schema")
	else:
		for table in schema.tables:
			for row in db.rows(str(table)):
				if row.size() != schema.tables[table].size(): _errors.append(str(table) + "：字段数量不符")
				for field in schema.tables[table]:
					if not row.has(field): _errors.append(str(table) + "：缺少字段 " + str(field)); continue
					var type_name = {TYPE_INT: "int", TYPE_FLOAT: "float", TYPE_BOOL: "bool", TYPE_STRING: "str"}.get(typeof(row[field]), "unknown")
					if type_name not in schema.tables[table][field]: _errors.append(str(table) + "." + str(field) + "：字段类型不符")
		for relation in schema.get("foreign_keys", []):
			var targets = {}
			for row in db.rows(str(relation.target)): targets[str(row[relation.target_column])] = true
			for row in db.rows(str(relation.table)):
				var values = db.list_values(row.get(relation.column, ""))
				if values.is_empty() and not relation.optional: values = [""]
				for value in values:
					if not targets.has(value) and value not in relation.allow: _errors.append(str(relation.table) + "." + str(relation.column) + "：引用不存在 " + str(value))
	for manifest in db.rows("config_manifest"):
		if db.rows(str(manifest.file)).size() != int(manifest.row_count): _errors.append("配置清单行数不符：" + str(manifest.file))
	var zh = {}; var en = {}
	for row in db.rows("localization_zh_cn"): zh[row.key] = row.text
	for row in db.rows("localization_en"): en[row.key] = row.text
	for key in zh:
		if not en.has(key): _errors.append("缺少英文文本：" + str(key))
	for key in en:
		if not zh.has(key): _errors.append("缺少中文文本：" + str(key))
	for table in db.table_names():
		for row in db.rows(str(table)):
			for field in ["name_key", "description_key", "title_key", "text_key", "body_key"]:
				if row.has(field) and (not zh.has(row[field]) or not en.has(row[field])): _errors.append("缺少双语文本：" + str(row[field]))
	for table in ["items", "bags"]:
		for row in db.rows(table):
			var icon_path = str(row.get("icon_ref", ""))
			if not ResourceLoader.exists(icon_path) and not FileAccess.file_exists(icon_path): _errors.append("缺少语义图标：" + str(row.id))
	for loadout in db.rows("character_loadouts"):
		var items = []
		for row in db.rows("starting_build_items"):
			if row.loadout_id == loadout.id: items.append(_entry(row, false))
		_layout(str(loadout.id), [{"definition_id": loadout.starting_bag_id, "uid": "starter_bag", "x": 0, "y": 0, "rotation": 0}], items)
	for enemy in db.rows("enemy_builds"):
		var bags = []; var items = []
		for row in db.rows("enemy_build_bags"):
			if row.enemy_build_id == enemy.id: bags.append(_entry(row, true))
		for row in db.rows("enemy_build_items"):
			if row.enemy_build_id == enemy.id: items.append(_entry(row, false))
		_layout(str(enemy.id), bags, items)
	for boss in db.rows("bosses"):
		var bags = db.boss_bags(str(boss.id))
		if bags.is_empty(): _errors.append(str(boss.id) + "：Boss缺少背包规则")
		for phase in [1, 2]:
			var items = []
			for row in db.rows("boss_build_items"):
				if row.boss_id == boss.id and int(row.phase) <= phase: items.append(_entry(row, false))
			_layout(str(boss.id) + "_phase_" + str(phase), bags, items)
	var counts = imported.get("counts", {}).duplicate(true)
	counts["native_layouts"] = _layouts
	return {"ok": _errors.is_empty(), "error": "" if _errors.is_empty() else str(_errors[0]),
		"errors": _errors.duplicate(), "warnings": _warnings.duplicate(), "counts": counts,
		"route_battle_range": imported.get("route_battle_range", {}).duplicate(true), "content_version": db.content_version, "content_sha256": db.content_sha256}

func _entry(row: Dictionary, is_bag: bool) -> Dictionary:
	return {"definition_id": row.get("bag_id" if is_bag else "item_id", ""), "uid": row.get("instance_id", ""),
		"x": int(row.get("origin_x", 0)), "y": int(row.get("origin_y", 0)), "rotation": int(row.get("rotation", 0))}

func _cells(entry: Dictionary, is_bag: bool, label: String) -> Array:
	var definition = db.get_row("bags" if is_bag else "items", str(entry.definition_id))
	if definition.is_empty():
		_errors.append(label + "：缺少物品或背包定义 " + str(entry.definition_id)); return []
	var shape_id = str(definition.shape_id)
	var shape_row = db.get_row("bag_shapes" if is_bag else "item_shapes", shape_id)
	var allowed = db.list_values(shape_row.get("allowed_rotations", ""))
	if str(entry.rotation) not in allowed: _errors.append(label + "：形状不允许旋转 " + str(entry.uid))
	var offsets = db.shape(shape_id, is_bag)
	if offsets.is_empty(): _errors.append(label + "：形状为空 " + shape_id); return []
	for turn in int(entry.rotation) / 90:
		for index in offsets.size(): offsets[index] = Vector2i(-offsets[index].y, offsets[index].x)
	var minimum = offsets[0]
	for cell in offsets: minimum = Vector2i(mini(minimum.x, cell.x), mini(minimum.y, cell.y))
	var result = []
	for cell in offsets: result.append(cell - minimum + Vector2i(int(entry.x), int(entry.y)))
	return result

func _layout(label: String, bags: Array, items: Array) -> void:
	_layouts += 1
	var covered = {}; var occupied = {}; var uids = {}
	for is_bag in [true, false]:
		for entry in bags if is_bag else items:
			if uids.has(entry.uid): _errors.append(label + "：重复实例ID " + str(entry.uid))
			uids[entry.uid] = true
			for cell in _cells(entry, is_bag, label):
				if cell.x < 0 or cell.y < 0 or cell.x >= int(db.value("grid_width", 9)) or cell.y >= int(db.value("grid_height", 7)): _errors.append(label + "：格子超出画布 " + str(entry.uid))
				if is_bag:
					if covered.has(cell): _errors.append(label + "：背包重叠 " + str(entry.uid))
					covered[cell] = true
				else:
					if not covered.has(cell): _errors.append(label + "：物品未放入背包 " + str(entry.uid))
					if occupied.has(cell): _errors.append(label + "：物品重叠 " + str(entry.uid))
					occupied[cell] = true
