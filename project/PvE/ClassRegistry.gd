extends Object

## 职业注册表读取器（Class Registry reader）。
## 数据源：res://PvE/class_registry.json —— 启用一个职业 = 把 enabled 改 true + 重跑验收。
## 本脚本只读数据不改数据；启动加载（RunFlow）、解锁判定（isClassUnlocked）都从这里取值。

const REGISTRY_PATH := "res://PvE/class_registry.json"

static var _entries: Array = []

static func entries() -> Array:
	if _entries.is_empty():
		var text := FileAccess.get_file_as_string(REGISTRY_PATH)
		if text.is_empty():
			push_error("ClassRegistry: registry file missing or empty: " + REGISTRY_PATH)
			return []
		var parsed = JSON.parse_string(text)
		if parsed == null or not (parsed is Dictionary) or not parsed.has("classes"):
			push_error("ClassRegistry: registry file malformed: " + REGISTRY_PATH)
			return []
		for entry in parsed["classes"]:
			if entry is Dictionary:
				_entries.push_back(entry)
		if _entries.is_empty():
			push_error("ClassRegistry: registry has no class entries: " + REGISTRY_PATH)
	return _entries

## 启用职业的枚举序号列表（isClassUnlocked 的唯一权威来源）。
static func enabled_indices() -> Array:
	var result: Array = []
	for entry in entries():
		if bool(entry.get("enabled", false)) and int(entry.get("enum_index", -1)) >= 0:
			result.push_back(int(entry["enum_index"]))
	return result

## 按职业 key 查枚举序号（替代代码里写死的 Classes_Full.XXX）。
static func index_of(key: String) -> int:
	for entry in entries():
		if str(entry.get("key", "")) == key:
			return int(entry.get("enum_index", -1))
	return -1

## 按 PvE 角色 id（art_key，即 run.character_id）查枚举序号；找不到返回 -1。
static func index_for_art_key(art_key: String) -> int:
	for entry in entries():
		if int(entry.get("enum_index", -2)) >= 0 and str(entry.get("art_key", "")) == art_key:
			return int(entry["enum_index"])
	return -1

## 按枚举序号查 PvE 角色 id（art_key）；找不到返回空串（调用方自行 fallback）。
static func art_key_for_index(idx: int) -> String:
	for entry in entries():
		if int(entry.get("enum_index", -2)) == idx and int(entry.get("enum_index", -2)) >= 0:
			return str(entry.get("art_key", ""))
	return ""
