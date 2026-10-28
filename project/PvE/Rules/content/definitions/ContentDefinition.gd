class_name ContentDefinition
extends Resource

@export_storage var _row: Dictionary = {}
var id: String:
	get: return str(_row.get("id", _row.get("key", "")))
	set(_unused): push_error("只读内容定义不能修改 ID")
var data: Dictionary:
	get: return _row.duplicate(true)
	set(_unused): push_error("只读内容定义不能替换数据")

func _init(row: Dictionary = {}):
	_row = row.duplicate(true)

func get_value(key: String, fallback = null):
	var result = _row.get(key, fallback)
	return result.duplicate(true) if result is Dictionary or result is Array else result

func list_field(key: String) -> Array:
	var result = get_value(key, "")
	return result if result is Array else Array(str(result).split("|", false))
