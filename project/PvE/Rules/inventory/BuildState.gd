class_name BuildState
extends RefCounted

var db
var undo_stack: Array = []
var redo_stack: Array = []

func _init(content = null):
	db = content

func create() -> Dictionary:
	return {"width": 9, "height": 7, "bags": [], "items": [], "storage": [], "storage_capacity": 2}

func snapshot(build: Dictionary) -> Dictionary:
	return build.duplicate(true)

func begin_phase(_build: Dictionary = {}) -> void:
	undo_stack.clear()
	redo_stack.clear()

func record(before: Dictionary, after: Dictionary) -> Dictionary:
	if before == after:
		return {"ok": true, "error": "", "changed": false}
	undo_stack.append({"before": before.duplicate(true), "after": after.duplicate(true)})
	while undo_stack.size() > int(db.value("undo_history_limit", 20)):
		undo_stack.pop_front()
	redo_stack.clear()
	return {"ok": true, "error": "", "changed": true}

func undo(build: Dictionary) -> Dictionary:
	if undo_stack.is_empty():
		return {"ok": false, "error": "no_undo", "message": "没有可撤销的操作。"}
	var change = undo_stack.pop_back()
	redo_stack.append(change)
	_replace(build, change.before)
	return {"ok": true, "error": "", "build": snapshot(build)}

func redo(build: Dictionary) -> Dictionary:
	if redo_stack.is_empty():
		return {"ok": false, "error": "no_redo", "message": "没有可重做的操作。"}
	var change = redo_stack.pop_back()
	undo_stack.append(change)
	_replace(build, change.after)
	return {"ok": true, "error": "", "build": snapshot(build)}

func compact_suggestion(build: Dictionary) -> Dictionary:
	var placement = PlacementService.new(db)
	var result = create()
	result.storage = build.get("storage", []).duplicate(true)
	result.storage_capacity = build.get("storage_capacity", 2)
	for layer in ["bags", "items"]:
		for entry in build.get(layer, []):
			var status = placement.auto_place(result, entry)
			if not status.ok:
				return {"ok": false, "error": "compact_no_space", "message": "紧凑排列建议无法容纳所有物品，现有构筑保留。"}
	return {"ok": true, "error": "", "build": result}

func _replace(build: Dictionary, source: Dictionary) -> void:
	build.clear()
	build.merge(source.duplicate(true), true)
