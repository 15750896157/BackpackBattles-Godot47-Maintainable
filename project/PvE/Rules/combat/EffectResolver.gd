class_name EffectResolver
extends RefCounted

const Params = preload("res://PvE/Rules/combat/SnapshotBuilder.gd")
var db

func _init(content = null): db = content

func resolve(engine, event: Dictionary) -> bool:
	var row: Dictionary = event.effect
	var source: Dictionary = engine.source(event.side, event.source_id)
	if source.is_empty() or not engine.condition(row, source, event): return false
	var params = Params.parse_params(row.get("effect_params", ""))
	var targets = engine.targets(source, row, event)
	if targets.is_empty(): return false
	var kind = str(row.get("effect_type", ""))
	var raw = params.get("value", params.get("amount", 0))
	var amount = float(raw) if str(raw).is_valid_float() else 0.0
	var duration = float(params.get("duration", 0.0))
	for target in targets:
		if engine.finished: break
		match kind:
			"physical_damage", "true_damage": engine.damage(event, int(target.side), amount, kind, "")
			"gain_armor": engine.gain_armor(event, int(target.side), amount)
			"heal": engine.heal(event, int(target.side), amount)
			"gain_stamina": engine.gain_stamina(event, int(target.side), amount)
			"apply_status":
				var id = str(params.get("status_id", ""))
				var count = int(params.get("stacks", 1))
				var value = str(raw).split(":")
				if value.size() >= 2:
					id = value[0]
					count = int(value[1])
				if params.has("repeat_pct"):
					id = str(event.get("payload", {}).get("status_id", ""))
					count = maxi(1, int(floor(float(event.get("payload", {}).get("stacks", 0)) * float(params.repeat_pct))))
				engine.apply_status(event, int(target.side), id, count, duration, not params.has("repeat_pct"))
			"remove_status":
				var id = str(params.get("status_id", "negative"))
				var removed = engine.statuses.remove(engine.actors[int(target.side)], id, int(params.get("stacks", amount)))
				engine.log_event(event, "STATUS_REMOVED", int(target.side), removed, {"status_id": id})
			"convert_status":
				var from = str(params.get("from", "poison"))
				var to = str(params.get("to", "regeneration"))
				var actor: Dictionary = engine.actors[int(target.side)]
				var count = engine.statuses.remove(actor, from, int(params.get("stacks", engine.statuses.stacks(actor, from))))
				engine.apply_status(event, int(target.side), to, int(floor(count * float(params.get("ratio", 1.0)))), duration, false)
			"modify_cooldown_pct", "modify_damage_flat", "modify_crit_chance", "modify_status_power":
				engine.add_modifier(event, target, kind.trim_prefix("modify_"), amount, duration)
			"advance_cooldown": engine.advance_cooldown(event, target, float(params.get("seconds", amount)))
			"gain_gold", "free_refresh":
				if int(target.side) == 0:
					var key = "gold" if kind == "gain_gold" else "free_refresh"
					engine.run_deltas[key] += int(params.get("count", amount))
				engine.log_event(event, "RUN_EFFECT", 0, int(params.get("count", amount)), {"effect_type": kind})
			"max_health":
				var actor: Dictionary = engine.actors[int(target.side)]
				actor.max_health = maxf(1.0, float(actor.max_health) + amount)
				actor.health = clampf(float(actor.health) + amount, 0.0, float(actor.max_health))
				if int(target.side) == 0: engine.run_deltas.max_health += amount
				engine.log_event(event, "MAX_HEALTH", int(target.side), amount)
			_:
				engine.log_event(event, "INVALID_EFFECT", int(target.side), 0, {"effect_type": kind})
				return false
	return true
