class_name ContentDB
extends RefCounted

const CACHE_PATH = "res://PvE/Rules/content/compiled/content.json"
var errors: Array = []
var content_version: String = ""
var content_sha256: String = ""
var _tables: Dictionary = {}
var _keys: Dictionary = {}
var _lookup: Dictionary = {}
var _rules: Dictionary = {}
var _locales: Dictionary = {}
var _ui_locales: Dictionary = {}
var _validation: Dictionary = {}

func _init(path = CACHE_PATH):
	load_content(path)

func load_content(path = CACHE_PATH) -> Dictionary:
	errors.clear()
	content_version = ""; content_sha256 = ""
	_tables.clear(); _keys.clear(); _lookup.clear(); _rules.clear(); _locales.clear(); _ui_locales.clear()
	_validation.clear()
	var parser = JSON.new()
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("内容缓存无法读取：" + str(path))
		return {"ok": false, "error": errors[0]}
	var data = parser.data
	if not data is Dictionary or data.get("format", "") != "backpack-pve-content" or int(data.get("schema_version", -1)) != 1:
		errors.append("内容缓存格式不受支持")
		return {"ok": false, "error": errors[0]}
	if not data.get("tables") is Dictionary or not data.get("columns") is Dictionary or not data.get("primary_keys") is Dictionary or not data.get("validation", {}) is Dictionary:
		errors.append("内容缓存表结构已损坏")
		return {"ok": false, "error": errors[0]}
	for table in data.tables:
		if not data.tables[table] is Array or not data.columns.get(table) is Dictionary or not data.primary_keys.get(table) is Array:
			errors.append("内容缓存表结构已损坏：" + str(table)); return {"ok": false, "error": errors[0]}
		for row in data.tables[table]:
			if not row is Dictionary:
				errors.append("内容缓存记录已损坏：" + str(table)); return {"ok": false, "error": errors[0]}
	_tables = data.get("tables", {}).duplicate(true)
	var schemas = data.get("columns", {})
	for table in _tables:
		for row in _tables[table]:
			for column in row:
				if schemas.get(table, {}).get(column, []) == ["int"]: row[column] = int(row[column])
			if row.get("value_type", "") == "int": row["value"] = int(row.value)
	_keys = data.get("primary_keys", {}).duplicate(true)
	_validation = data.get("validation", {}).duplicate(true)
	content_version = str(data.get("content_version", ""))
	content_sha256 = str(data.get("content_sha256", ""))
	for table in _tables:
		_lookup[table] = {}
		for row in _tables[table]:
			var components = []
			for column in _keys.get(table, ["id"]): components.append(_key_string(row.get(column, "")))
			_lookup[table]["|".join(components)] = row
	for row in _tables.get("game_rules", []): _rules[row.key] = row.value
	for language in ["zh_CN", "en"]:
		_locales[language] = {}
		var table = "localization_zh_cn" if language == "zh_CN" else "localization_en"
		for row in _tables.get(table, []): _locales[language][row.key] = row.text
		var ui_path = "res://PvE/Rules/content/ui_zh.json" if language == "zh_CN" else "res://PvE/Rules/content/ui_en.json"
		var ui = JSON.parse_string(FileAccess.get_file_as_string(ui_path)) if FileAccess.file_exists(ui_path) else {}
		_ui_locales[language] = ui if ui is Dictionary else {}
	return {"ok": true, "error": "", "content_version": content_version, "tables": _tables.size()}

func rows(table: String) -> Array:
	return _tables.get(table.trim_suffix(".csv"), []).duplicate(true)

func table_names() -> Array:
	return _tables.keys().duplicate()

func validation_info() -> Dictionary:
	return _validation.duplicate(true)

func get_row(table: String, id: String) -> Dictionary:
	return _lookup.get(table.trim_suffix(".csv"), {}).get(id, {}).duplicate(true)

func value(key: String, fallback = null):
	return _copy(_rules.get(key, fallback))

func text(key: String, language = "zh_CN") -> String:
	var locale = "zh_CN" if str(language).to_lower().begins_with("zh") else "en"
	return str(_locales.get(locale, {}).get(key, _ui_locales.get(locale, {}).get(key, key)))

func shape(shape_id: String, is_bag = false) -> Array:
	var result = []
	var row = get_row("bag_shapes" if is_bag else "item_shapes", shape_id)
	for cell in list_values(row.get("cells", "")):
		var coords = str(cell).split(":")
		if coords.size() == 2: result.append(Vector2i(int(coords[0]), int(coords[1])))
	return result

static func list_values(raw) -> Array:
	if raw is Array: return raw.duplicate(true)
	if raw == null or str(raw).is_empty(): return []
	return Array(str(raw).split("|", false))

static func parse_params(raw) -> Dictionary:
	if raw is Dictionary: return raw.duplicate(true)
	var result = {}
	for token in list_values(raw):
		var separator = str(token).find(":")
		if separator < 0: result[str(token)] = true
		else: result[str(token).substr(0, separator)] = _scalar(str(token).substr(separator + 1))
	return result

static func _scalar(raw: String):
	if raw == "true": return true
	if raw == "false": return false
	if raw.is_valid_int(): return int(raw)
	if raw.is_valid_float(): return float(raw)
	return raw

static func _copy(value):
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _key_string(value) -> String:
	return str(int(value)) if value is float and value == int(value) else str(value)

func boss_bags(boss_id: String) -> Array:
	var result = []
	for token in list_values(get_row("bosses", boss_id).get("bag_layout", "")):
		var part = str(token).split(":")
		if part.size() == 4:
			result.append({"uid": boss_id + "_bag_" + str(result.size()+1), "definition_id": part[0],
				"x": int(part[1]), "y": int(part[2]), "rotation": int(part[3]), "used": true,
				"purchased_visit": -1, "purchase_price": 0})
	return result

func get_definition(table: String, id: String) -> Resource:
	var types = {"items": "Item", "bags": "Bag", "recipes": "Recipe", "characters": "Character",
		"encounter_templates": "Encounter", "enemy_builds": "EnemyBuild", "events": "Event",
		"reward_tables": "Reward", "difficulty_levels": "Difficulty", "statuses": "Status"}
	var row = get_row(table, id)
	if row.is_empty() or not types.has(table): return null
	return load("res://PvE/Rules/content/definitions/" + types[table] + "Definition.gd").new(row)
