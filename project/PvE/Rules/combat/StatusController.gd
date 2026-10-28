class_name StatusController
extends RefCounted

var db
var definitions: Dictionary = {}

func _init(content = null):
	db = content
	if db != null:
		for row in db.rows("statuses"): definitions[str(row.id)] = row

func definition(id: String) -> Dictionary:
	return definitions.get(id, {})

func apply(actor: Dictionary, id: String, amount: int, duration: float, tick: int, step: float, source_id: String, source_side: int) -> Dictionary:
	var def = definition(id)
	if def.is_empty() or amount <= 0: return {"added": 0, "new": false, "error": "unknown_or_empty_status"}
	var old: Dictionary = actor.statuses.get(id, {})
	var previous = int(old.get("stacks", 0))
	var count = mini(int(def.get("stack_cap", 99)), previous + amount)
	var interval = float(def.get("tick_interval", 0.0))
	var is_timed = str(def.get("decay_rule", "")) == "duration"
	var seconds = duration if duration > 0.0 else float(def.get("default_duration", 0.0))
	var expires = tick + maxi(1, int(ceil(seconds / step))) if is_timed else -1
	var state = {"stacks": count, "expires": maxi(int(old.get("expires", -1)), expires),
		"next_tick": int(old.get("next_tick", tick + maxi(1, int(round(interval / step))))),
		"source_id": source_id, "source_side": source_side}
	actor.statuses[id] = state
	return {"added": count - previous, "new": previous == 0, "error": ""}

func remove(actor: Dictionary, id: String, amount: int) -> int:
	var removed = 0
	var keys: Array = [id]
	if id.is_empty() or id == "negative":
		keys = actor.statuses.keys()
		keys.sort()
	for key in keys:
		if not actor.statuses.has(key): continue
		if (id.is_empty() or id == "negative") and str(definition(key).get("polarity", "")) != "negative": continue
		var current = int(actor.statuses[key].stacks)
		var taking = mini(current, maxi(0, amount - removed))
		actor.statuses[key].stacks = current - taking
		removed += taking
		if int(actor.statuses[key].stacks) <= 0: actor.statuses.erase(key)
		if removed >= amount: break
	return removed

func stacks(actor: Dictionary, id: String) -> int:
	return int(actor.statuses.get(id, {}).get("stacks", 0))

func value(actor: Dictionary, id: String) -> float:
	return stacks(actor, id) * float(definition(id).get("value_per_stack", 0.0))

func due(actor: Dictionary, tick: int, step: float) -> Array:
	var actions: Array = []
	var keys = actor.statuses.keys()
	keys.sort()
	for id in keys:
		var state: Dictionary = actor.statuses[id]
		var def: Dictionary = definition(id)
		if int(state.expires) >= 0 and tick >= int(state.expires):
			actor.statuses.erase(id)
			continue
		var interval = float(def.get("tick_interval", 0.0))
		if interval <= 0.0 or str(def.get("decay_rule", "")) == "duration" or tick < int(state.next_tick): continue
		state.next_tick = tick + maxi(1, int(round(interval / step)))
		var count = int(state.stacks)
		var amount = count
		if str(def.get("tick_rule", "")) == "damage_half_stacks_min1": amount = maxi(1, int(floor(count * 0.5)))
		actions.append({"status_id": id, "kind": "heal" if id == "regeneration" else "true_damage",
			"amount": amount, "source_id": state.source_id, "source_side": state.source_side})
		if str(def.get("decay_rule", "")) == "decrease_flat":
			state.stacks = maxi(0, count - 1)
			if int(state.stacks) == 0: actor.statuses.erase(id)
	return actions
