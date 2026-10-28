class_name CombatEventQueue
extends RefCounted

var db
var pending: Array = []
var seen_ids: Dictionary = {}
var next_sequence: int = 0
var depth_limit: int = 8
var rejected: Array = []

func _init(content = null):
	db = content
	if db != null: depth_limit = mini(8, int(db.value("chain_depth_limit", 8)))

func push(event: Dictionary) -> bool:
	var id = str(event.get("event_id", ""))
	if id.is_empty():
		id = "event_%09d" % next_sequence
		event["event_id"] = id
	if seen_ids.has(id): return false
	seen_ids[id] = true
	event["sequence"] = next_sequence
	next_sequence += 1
	if int(event.get("depth", 0)) > depth_limit:
		rejected.append(event.duplicate(true))
		return false
	pending.append(event)
	return true

func pop_due(tick: int) -> Dictionary:
	if pending.is_empty(): return {}
	pending.sort_custom(_before)
	if int(pending[0].get("tick", 0)) > tick: return {}
	return pending.pop_front()

func clear() -> void:
	pending.clear()
	seen_ids.clear()
	rejected.clear()
	next_sequence = 0

func _before(a: Dictionary, b: Dictionary) -> bool:
	for key in ["tick", "priority", "side"]:
		var first = int(a.get(key, 0))
		var second = int(b.get(key, 0))
		if first != second: return first < second
	var first_id = str(a.get("sort_source", a.get("source_id", "")))
	var second_id = str(b.get("sort_source", b.get("source_id", "")))
	if first_id != second_id: return first_id < second_id
	return int(a.get("sequence", 0)) < int(b.get("sequence", 0))
