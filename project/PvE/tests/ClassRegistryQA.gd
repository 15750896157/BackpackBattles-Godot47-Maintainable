extends Node

var checks = 0
var failures: Array = []
var output = ""

func check(value, label):
	checks += 1
	if not value: failures.append(label); print("CLASS_REGISTRY_FAILURE ", label)
	return value

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func run_tests():
	while not Expedition.initialized: await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	var registry = load("res://PvE/ClassRegistry.gd")
	var entries = registry.entries()

	# 1. 注册表结构：8 条全录（7 个枚举职业 + 1 个未解锁占位）。
	check(entries.size() == 8, "registry has 8 entries (got %d)" % entries.size())

	# 2. 占位条目 NotUnlocked 必须存在且永不启用（无存档槽、零加载）。
	var has_placeholder = false
	for entry in entries:
		if str(entry.get("key", "")) == "NotUnlocked":
			has_placeholder = true
			check(int(entry.get("enum_index", -2)) == -1, "NotUnlocked has no save slot (enum_index -1)")
			check(not bool(entry.get("enabled", true)), "NotUnlocked stays disabled")
	check(has_placeholder, "NotUnlocked placeholder entry exists")

	# 3. 存档槽兼容：enum_index>=0 的条目必须与 Classes_Full 枚举一一对应。
	var enum_keys: Array = Game.Classes_Full.keys()
	var enum_values: Array = Game.Classes_Full.values()
	var slotted: Array = []
	for entry in entries:
		var idx = int(entry.get("enum_index", -2))
		if idx >= 0:
			slotted.push_back(idx)
			var pos = enum_values.find(idx)
			check(pos >= 0, "enum_index %d matches a Classes_Full slot" % idx)
			if pos >= 0:
				check(str(enum_keys[pos]) == str(entry.get("key", "")), "registry key matches enum name at %d" % idx)
	slotted.sort()
	var expected: Array = enum_values.duplicate()
	expected.sort()
	check(slotted == expected, "slotted indices cover every enum value")
	check(enum_values.size() == 7, "Classes_Full still has 7 save slots (got %d)" % enum_values.size())

	# 4. isClassUnlocked 与注册表一致（解锁判定唯一权威在注册表）。
	for entry in entries:
		var idx = int(entry.get("enum_index", -2))
		if idx >= 0:
			check(Game.isClassUnlocked(idx) == bool(entry.get("enabled", false)), "isClassUnlocked follows registry at %d" % idx)

	# 5. 启动加载：classResources 尺寸与槽位加载均跟随注册表。
	check(Game.classResources.size() == 7, "classResources has 7 slots (got %d)" % Game.classResources.size())
	for entry in entries:
		var idx = int(entry.get("enum_index", -2))
		if idx >= 0 and idx < Game.classResources.size():
			if bool(entry.get("enabled", false)):
				check(Game.classResources[idx] != null, "enabled class %s loaded at start" % str(entry["key"]))
			else:
				check(Game.classResources[idx] == null, "disabled class %s skipped at start" % str(entry["key"]))

	# 6. 资源红线：enabled 职业的 .tres 必须存在；磁盘基线四件套（Ranger/Reaper/Berserker/Pyromancer）
	#    无论启用与否都不许消失（僵尸职业不删）。Mage/Adventurer/Engineer 原版从无 .tres，不检查。
	var disk_baseline: Array = ["Ranger", "Reaper", "Berserker", "Pyromancer"]
	for entry in entries:
		var key = str(entry.get("key", ""))
		var idx = int(entry.get("enum_index", -2))
		var path = str(entry.get("tres_path", ""))
		if idx >= 0 and not path.is_empty():
			if bool(entry.get("enabled", false)) or key in disk_baseline:
				check(ResourceLoader.exists(path), "class resource kept on disk: " + path)

	# 7. 双轨映射护栏：PvE 角色 id（art_key）与注册表一一对应、回环一致。
	var seen_art_keys: Array = []
	for entry in entries:
		var art_key = str(entry.get("art_key", ""))
		var idx = int(entry.get("enum_index", -2))
		if not art_key.is_empty() and idx >= 0:
			check(not seen_art_keys.has(art_key), "art_key unique: " + art_key)
			seen_art_keys.push_back(art_key)
			check(registry.art_key_for_index(idx) == art_key, "art_key round-trip index->art_key at " + str(idx))
			check(registry.index_for_art_key(art_key) == idx, "art_key round-trip art_key->index for " + art_key)
	# 8. 启用职业的 PvE 角色 id 必须在可选角色清单里（UI/存档/美术三链共用）。
	var selectable: Array = Expedition.db.release_catalog.get("selectable_characters", [])
	for entry in entries:
		if bool(entry.get("enabled", false)) and int(entry.get("enum_index", -2)) >= 0:
			var art_key = str(entry.get("art_key", ""))
			check(not art_key.is_empty() and art_key in selectable, "enabled class maps to selectable character: " + str(entry.get("key", "")))
	# 9. 可选角色数据完备性：每个角色 id 在 characters 表有行、初始装备不为空、注册表查得到。
	for role_id in selectable:
		var row = Expedition.db.get_row("characters", str(role_id))
		check(not row.is_empty(), "selectable character has a data row: " + str(role_id))
		check(registry.index_for_art_key(str(role_id)) >= 0, "selectable character maps into registry: " + str(role_id))
		check(Expedition.db.starting_loadouts(str(role_id)).size() > 0, "selectable character has loadouts: " + str(role_id))

	finish()

func finish():
	DirAccess.make_dir_recursive_absolute(output)
	var file = FileAccess.open(output.path_join("class-registry-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty()}, "\t"))
	file.close()
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
