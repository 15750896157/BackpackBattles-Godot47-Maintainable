class_name CombatEngine
extends RefCounted

const QueueClass = preload("res://PvE/Rules/combat/CombatEventQueue.gd")
const StatusClass = preload("res://PvE/Rules/combat/StatusController.gd")
const ResolverClass = preload("res://PvE/Rules/combat/EffectResolver.gd")
const Params = preload("res://PvE/Rules/combat/SnapshotBuilder.gd")
var db
var actors: Array = []
var queue
var statuses
var resolver
var step: float = 0.05
var tick: int = 0
var finished: bool = false
var winner_side: int = 1
var defeat_reason: String = ""
var rng_state: int = 1
var event_counter: int = 0
var full_events: Array = []
var timeline: Array = []
var item_stats: Dictionary = {}
var root_activations: Dictionary = {}
var root_advances: Dictionary = {}
var root_contexts: Dictionary = {}
var run_deltas: Dictionary = {}
var status_totals: Dictionary = {}
var fatigue_count: int = 0
var fatigue_started: bool = false
var next_fatigue_tick: int = 0
var event_hash: HashingContext
var consumed_events: int = 0
var final_damage_type: String = ""
var rng_purpose_counts: Dictionary = {}

func _init(content = null): db = content

func simulate(player_snapshot: Dictionary, enemy_snapshot: Dictionary, seed: int) -> Dictionary:
	for snapshot in [player_snapshot, enemy_snapshot]:
		var validation = validate_snapshot(snapshot)
		if not validation.ok: return {"ok": false, "error": validation.error, "winner_side": 1, "elapsed_time": 0.0}
	if str(player_snapshot.get("content_version", "")) != str(enemy_snapshot.get("content_version", "")):
		return {"ok": false, "error": "snapshot_content_mismatch", "winner_side": 1, "elapsed_time": 0.0}
	var content_error = _validate_content_hash(player_snapshot, enemy_snapshot)
	if not content_error.is_empty(): return {"ok": false, "error": content_error, "winner_side": 1, "elapsed_time": 0.0}
	_reset(seed)
	actors = [_actor(player_snapshot.duplicate(true), 0), _actor(enemy_snapshot.duplicate(true), 1)]
	_sample()
	_check_death()
	_queue_combat_starts()
	_drain()
	var max_ticks = int(ceil(float(_rule("combat_safety_seconds", 600.0)) / step))
	while not finished and tick < max_ticks:
		tick += 1
		for actor in actors:
			if tick <= int(actor.get("starvation_until_tick", 0)): actor.starvation = _number(float(actor.starvation) + step)
			actor.stamina = _number(minf(float(actor.stamina_max), float(actor.stamina) + float(actor.stamina_regen) * step))
			_expire_modifiers(actor.modifiers)
			for id in actor.ordered_sources:
				var item: Dictionary = actor.sources[id]
				_expire_modifiers(item.modifiers)
				if not bool(item.active): continue
				if tick <= int(item.get("starvation_until_tick", 0)):
					var key = _stats_key(int(actor.side), str(id))
					item_stats[key].stamina_starvation = _number(float(item_stats[key].stamina_starvation) + step)
				if float(item.cooldown) > 0.0:
					var speed = (1.0 + statuses.value(actor, "haste")) * (1.0 - minf(float(_rule("slow_cap", 0.5)), statuses.value(actor, "slow")))
					item.progress = _number(float(item.progress) + step * maxf(0.0, speed))
					if float(item.progress) + 0.000001 >= _cooldown(actor, item) and tick >= int(item.retry_tick):
						var event = _event(actor.side, id, "activate", _priority("cooldown_ready"), {"trigger": "cooldown_ready"})
						event["rows"] = _rows_for(item, "cooldown_ready")
						if not event.rows.is_empty(): queue.push(event)
				for row in _rows_for(item, "interval"):
					var params = Params.parse_params(row.get("effect_params", ""))
					var interval = float(params.get("interval", row.get("interval", 1.0)))
					var interval_ticks = maxi(1, int(round(interval / step)))
					if tick % interval_ticks == 0:
						var event = _event(actor.side, id, "activate", _priority("interval"), {"trigger": "interval"})
						event["rows"] = [row]
						queue.push(event)
			for action in statuses.due(actor, tick, step):
				var event = _event(int(action.source_side), str(action.source_id), "status_tick", 40, action)
				event["target_side"] = int(actor.side)
				queue.push(event)
			_schedule_boss(actor)
		var fatigue_tick = int(round(float(_rule("fatigue_start_seconds", 85.0)) / step))
		if not fatigue_started and tick >= fatigue_tick:
			fatigue_started = true
			next_fatigue_tick = tick + maxi(1, int(round(float(_rule("fatigue_tick_seconds", 2.0)) / step)))
			var event = _event(0, "__fatigue__", "fatigue_start", 5)
			queue.push(event)
		if fatigue_started and tick >= next_fatigue_tick:
			next_fatigue_tick += maxi(1, int(round(float(_rule("fatigue_tick_seconds", 2.0)) / step)))
			queue.push(_event(0, "__fatigue__", "fatigue", 5))
		_drain()
		if tick % maxi(1, int(round(0.5 / step))) == 0: _sample()
	if not finished:
		finished = true
		winner_side = 1
		defeat_reason = "safety_limit"
	_sample(true)
	var hash_value = event_hash.finish().hex_encode()
	var result = {"ok": true, "error": "", "result_version": 2, "content_sha256": str(db.content_sha256) if db != null else "", "winner_side": winner_side, "defeat_reason": defeat_reason,
		"elapsed_time": _number(tick * step), "player_remaining_health": _number(actors[0].health), "enemy_remaining_health": _number(actors[1].health),
		"item_stats_by_instance_id": item_stats, "status_totals": status_totals, "stamina_starvation_time": [actors[0].starvation, actors[1].starvation],
		"key_events": _key_events(), "full_events": full_events, "timeline": timeline, "rng_final_state": rng_state,
		"run_deltas": run_deltas, "final_damage_type": final_damage_type, "total_healing": actors[0].total_healing,
		"peak_armor": actors[0].peak_armor, "event_count": consumed_events, "boss_phases": [actors[0].phase, actors[1].phase], "rng_purpose_counts": rng_purpose_counts}
	result["replay_digest"] = (JSON.stringify(result, "", true, true) + hash_value).sha256_text()
	return result

func preview(player_snapshot: Dictionary, enemy_snapshot: Dictionary = {}) -> Dictionary:
	var opponent = enemy_snapshot
	if opponent.is_empty():
		opponent = {"content_version": player_snapshot.get("content_version", ""), "owner_id": "preview",
			"base_stats": {"health": 1000000.0, "max_health": 1000000.0, "crit_chance": 0.0}, "items": []}
	for snapshot in [player_snapshot, opponent]:
		var validation = validate_snapshot(snapshot)
		if not validation.ok: return {"ok": false, "error": validation.error, "items": {}}
	if str(player_snapshot.get("content_version", "")) != str(opponent.get("content_version", "")):
		return {"ok": false, "error": "snapshot_content_mismatch", "items": {}}
	var content_error = _validate_content_hash(player_snapshot, opponent)
	if not content_error.is_empty(): return {"ok": false, "error": content_error, "items": {}}
	_reset(1)
	actors = [_actor(player_snapshot.duplicate(true), 0), _actor(opponent.duplicate(true), 1)]
	_queue_combat_starts()
	_drain()
	var result: Dictionary = {}
	var actor: Dictionary = actors[0]
	for id in actor.ordered_sources:
		var item: Dictionary = actor.sources[id]
		if int(item.category) != 2: continue
		var base_damage = 0.0
		var current_damage = 0.0
		var available_damage = 0.0
		var conditions: Dictionary = {}
		for row in item.get("effects", []):
			if str(row.get("effect_type", "")) not in ["physical_damage", "true_damage"]: continue
			var params = Params.parse_params(row.get("effect_params", ""))
			var value = float(params.get("value", params.get("amount", 0.0)))
			base_damage += maxf(0.0, value)
			var damage_value = _raw_damage(actor, item, value, false)
			current_damage += damage_value
			var condition_met = condition(row, item, _event(0, id, "preview", 0))
			conditions[str(row.get("id", ""))] = condition_met
			if condition_met: available_damage += damage_value
		result[id] = {"base_cooldown": _number(float(item.cooldown)),
			"cooldown": _number(_cooldown(actor, item)) if float(item.cooldown) > 0.0 else 0.0,
			"base_damage": _number(base_damage), "damage": _number(current_damage),
			"crit_chance": _number(_crit_chance(actor, item)),
			"modifiers": (actor.modifiers + item.modifiers).duplicate(true), "active": item.active,
			"conditions": conditions, "can_deal_damage": item.active and available_damage > 0.0,
			"damage_when_conditions_met": _number(available_damage)}
	return {"ok": true, "error": "", "items": result, "scope": "combat_start_only", "tick": tick,
		"excludes": ["critical_damage", "enemy_defense", "later_triggers", "run_deltas"]}

func _queue_combat_starts() -> void:
	for side in 2:
		for id in actors[side].ordered_sources:
			var item: Dictionary = actors[side].sources[id]
			var rows = _rows_for(item, "combat_start")
			if not rows.is_empty() and item.active:
				var event = _event(side, id, "activate", int(item.get("category", 2)), {}, 0, "", 0)
				event["rows"] = rows
				event["sort_source"] = "%04d:%04d:%s" % [int(item.get("y", 0)), int(item.get("x", 0)), id]
				queue.push(event)

func validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.get("ok", true) == false: return {"ok": false, "error": str(snapshot.get("error", "invalid_snapshot"))}
	if not snapshot.get("base_stats") is Dictionary or not snapshot.get("items") is Array: return {"ok": false, "error": "snapshot_schema"}
	var stats: Dictionary = snapshot.base_stats
	if not _finite_number(stats.get("max_health")) or float(stats.max_health) <= 0.0: return {"ok": false, "error": "snapshot_health"}
	for field in ["health", "stamina_max", "stamina_regen", "crit_chance", "crit_multiplier", "damage_scalar", "status_scalar"]:
		if stats.has(field) and (not _finite_number(stats[field]) or float(stats[field]) < 0.0): return {"ok": false, "error": "snapshot_stat_" + field}
	if stats.has("health") and float(stats.health) > float(stats.max_health): return {"ok": false, "error": "snapshot_stat_health"}
	for field in ["passives", "bag_effects", "encounter_modifiers", "boss_phases"]:
		if not snapshot.get(field, []) is Array: return {"ok": false, "error": "snapshot_" + field}
		for row in snapshot.get(field, []):
			if not row is Dictionary: return {"ok": false, "error": "snapshot_" + field}
			if field == "boss_phases":
				if not _finite_number(row.get("phase")) or not _finite_number(row.get("health_threshold_pct")) or int(row.phase) not in [1, 2]: return {"ok": false, "error": "snapshot_boss_phases"}
			elif not row.get("id") is String or str(row.id).is_empty(): return {"ok": false, "error": "snapshot_" + field}
	var ids: Dictionary = {}
	for item in snapshot.items:
		if not item is Dictionary: return {"ok": false, "error": "snapshot_item_schema"}
		var id = str(item.get("instance_id", ""))
		if id.is_empty() or ids.has(id) or id.begins_with("__"): return {"ok": false, "error": "snapshot_duplicate_uid"}
		ids[id] = true
		for field in ["cooldown", "stamina_cost", "x", "y", "rotation", "phase"]:
			if item.has(field) and (not _finite_number(item[field]) or float(item[field]) < 0.0): return {"ok": false, "error": "snapshot_item_" + field}
		if not item.get("effects", []) is Array or not item.get("static_modifiers", []) is Array or not item.get("tags", []) is Array or not item.get("relations", {}) is Dictionary:
			return {"ok": false, "error": "snapshot_item_schema"}
		for targets_in_relation in item.get("relations", {}).values():
			if not targets_in_relation is Array: return {"ok": false, "error": "snapshot_relations"}
		for modifier in item.get("static_modifiers", []):
			if not modifier is Dictionary or not modifier.get("stat") is String or not _finite_number(modifier.get("value")): return {"ok": false, "error": "snapshot_modifier"}
		for row in item.get("effects", []):
			if not row is Dictionary or not row.get("effect_params", "") is String and not row.get("effect_params", {}) is Dictionary: return {"ok": false, "error": "snapshot_effect_schema"}
	return {"ok": true, "error": ""}

func _finite_number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _validate_content_hash(first: Dictionary, second: Dictionary) -> String:
	if first.has("content_sha256") and second.has("content_sha256") and str(first.content_sha256) != str(second.content_sha256): return "snapshot_content_hash_mismatch"
	if db != null:
		for snapshot in [first, second]:
			if snapshot.has("content_sha256") and str(snapshot.content_sha256) != str(db.content_sha256): return "snapshot_content_hash_outdated"
	return ""

func _reset(seed: int) -> void:
	step = clampf(float(_rule("fixed_step_seconds", 0.05)), 0.001, 0.1)
	tick = 0
	finished = false
	winner_side = 1
	defeat_reason = ""
	rng_state = posmod(seed, 2147483647)
	if rng_state == 0: rng_state = 1
	event_counter = 0
	consumed_events = 0
	full_events = []
	timeline = []
	item_stats = {}
	root_activations = {}
	root_advances = {}
	root_contexts = {}
	status_totals = {"0": {}, "1": {}}
	run_deltas = {"gold": 0, "free_refresh": 0, "max_health": 0.0}
	fatigue_count = 0
	fatigue_started = false
	final_damage_type = ""
	rng_purpose_counts = {}
	queue = QueueClass.new(db)
	statuses = StatusClass.new(db)
	resolver = ResolverClass.new(db)
	event_hash = HashingContext.new()
	event_hash.start(HashingContext.HASH_SHA256)

func _actor(snapshot: Dictionary, side: int) -> Dictionary:
	var stats: Dictionary = snapshot.base_stats
	var actor = {"side": side, "owner_id": str(snapshot.get("owner_id", "")), "health": clampf(float(stats.get("health", stats.max_health)), 0.0, float(stats.max_health)),
		"max_health": float(stats.max_health), "armor": 0.0, "stamina_max": float(stats.get("stamina_max", 10)),
		"stamina": float(stats.get("stamina_max", 10)), "stamina_regen": float(stats.get("stamina_regen", 1.7)),
		"crit_chance": float(stats.get("crit_chance", 0.05)), "crit_multiplier": float(stats.get("crit_multiplier", 1.5)),
		"damage_scalar": float(stats.get("damage_scalar", 1.0)), "status_scalar": float(stats.get("status_scalar", 1.0)),
		"statuses": {}, "modifiers": [], "sources": {}, "ordered_sources": [], "starvation": 0.0, "starvation_until_tick": 0, "total_healing": 0.0,
		"peak_armor": 0.0, "low_health_emitted": false, "negative_seen": {}, "weapon_shapes_seen": {},
		"phase": 1, "phases": snapshot.get("boss_phases", []), "pending_phase": 0, "phase_due": -1,
		"boss_next_tick": -1, "boss_params": {}, "boss_enraged": false, "snapshot": snapshot}
	var ordered: Array = snapshot.items.duplicate(true)
	ordered.sort_custom(func(a, b):
		if int(a.get("y", 0)) != int(b.get("y", 0)): return int(a.get("y", 0)) < int(b.get("y", 0))
		if int(a.get("x", 0)) != int(b.get("x", 0)): return int(a.get("x", 0)) < int(b.get("x", 0))
		return str(a.instance_id) < str(b.instance_id))
	for item in ordered:
		item["category"] = 2
		_register_source(actor, item)
	for passive in snapshot.get("passives", []):
		var row = passive.duplicate(true)
		row["internal_cooldown"] = 0.0
		row["target_selector"] = "self"
		row["spatial_template_id"] = "none"
		_register_source(actor, {"instance_id": "__passive__:" + str(row.id), "def_id": str(row.id), "effects": [row], "category": 0, "tags": []})
	for bag in snapshot.get("bag_effects", []): _register_source(actor, {"instance_id": "__bag__:" + str(bag.id), "def_id": str(bag.id), "effects": [bag], "phase": int(bag.get("phase", 1)), "category": 1, "tags": []})
	for modifier in snapshot.get("encounter_modifiers", []):
		var row = modifier.duplicate(true)
		row["condition_id"] = "always"
		row["target_selector"] = "self"
		row["spatial_template_id"] = "none"
		_register_source(actor, {"instance_id": "__affix__:" + str(row.id), "def_id": str(row.id), "effects": [row], "category": 0, "tags": []})
	actor.ordered_sources.sort_custom(func(a, b):
		var first: Dictionary = actor.sources[a]
		var second: Dictionary = actor.sources[b]
		if int(first.category) != int(second.category): return int(first.category) < int(second.category)
		if int(first.get("y", 0)) != int(second.get("y", 0)): return int(first.get("y", 0)) < int(second.get("y", 0))
		if int(first.get("x", 0)) != int(second.get("x", 0)): return int(first.get("x", 0)) < int(second.get("x", 0))
		return str(a) < str(b))
	if not actor.phases.is_empty():
		_register_source(actor, {"instance_id": "__boss__", "def_id": str(snapshot.get("boss_rule_id", "boss")), "effects": [], "category": 0, "tags": []})
		_set_phase(actor, actor.phases[0])
	return actor

func _register_source(actor: Dictionary, item: Dictionary) -> void:
	var id = str(item.instance_id)
	item["side"] = int(actor.side)
	item["active"] = int(item.get("phase", 1)) <= 1
	item["cooldown"] = float(item.get("cooldown", 0.0))
	item["stamina_cost"] = float(item.get("stamina_cost", 0.0))
	item["progress"] = 0.0
	item["retry_tick"] = 0
	item["starvation_until_tick"] = 0
	item["modifiers"] = []
	item["effect_counts"] = {}
	item["last_effect_tick"] = {}
	item["relations"] = item.get("relations", {})
	item["tags"] = item.get("tags", [])
	for modifier in item.get("static_modifiers", []):
		var copy = modifier.duplicate(true)
		copy["expires"] = -1
		item.modifiers.append(copy)
	actor.sources[id] = item
	actor.ordered_sources.append(id)
	item_stats[_stats_key(actor.side, id)] = {"instance_id": id, "def_id": str(item.get("def_id", "")), "side": actor.side,
		"damage": 0.0, "health_damage": 0.0, "healing": 0.0, "armor": 0.0, "triggers": 0, "status_applied": 0, "stamina_starvation": 0.0}

func source(side: int, id: String) -> Dictionary:
	return actors[side].sources.get(id, {})

func _event(side: int, id: String, kind: String, priority: int, payload: Dictionary = {}, depth: int = 0, root_id: String = "", due: int = -1) -> Dictionary:
	var event_id = "e%09d" % event_counter
	event_counter += 1
	if root_id.is_empty(): root_id = event_id
	return {"event_id": event_id, "root_id": root_id, "tick": tick if due < 0 else due, "priority": priority, "side": side,
		"source_id": id, "kind": kind, "depth": depth, "payload": payload}

func _drain() -> void:
	var processed = 0
	while not finished:
		var event = queue.pop_due(tick)
		if event.is_empty(): break
		processed += 1
		if processed > 10000:
			log_event(event, "CHAIN_LIMIT_REACHED", int(event.side), 0, {"reason": "event_budget"})
			queue.pending.clear()
			break
		match str(event.kind):
			"activate": _activate(event)
			"effect":
				if float(actors[int(event.side)].health) <= 0.0: continue
				if resolver.resolve(self, event):
					var item = source(event.side, event.source_id)
					var effect_id = str(event.effect.get("id", event.effect.get("effect_type", "")))
					item.effect_counts[effect_id] = int(item.effect_counts.get(effect_id, 0)) + 1
					item.last_effect_tick[effect_id] = tick
					_mark_passive(item, event)
					_check_death()
			"status_tick":
				if str(event.payload.kind) == "heal": heal(event, int(event.target_side), float(event.payload.amount), false, true)
				else: damage(event, int(event.target_side), float(event.payload.amount), "true_damage", str(event.payload.status_id))
				_check_death()
			"fatigue_start":
				log_event(event, "FATIGUE_START", -1, 0)
				for side in 2: _emit_trigger("fatigue_start", side, event, {})
			"fatigue":
				fatigue_count += 1
				var amount = float(_rule("fatigue_base_damage", 4.0)) + (fatigue_count - 1) * float(_rule("fatigue_damage_growth", 3.0))
				for side in 2:
					actors[side].health = maxf(0.0, float(actors[side].health) - amount)
					log_event(event, "FATIGUE_DAMAGE", side, amount)
				final_damage_type = "fatigue"
				_check_death()
			"boss_phase": _set_phase(actors[int(event.side)], event.payload)
			"boss_rule": _boss_rule(event)
	for rejected in queue.rejected: log_event(rejected, "CHAIN_LIMIT_REACHED", int(rejected.side), rejected.depth)
	queue.rejected.clear()

func _activate(event: Dictionary) -> void:
	var item = source(event.side, event.source_id)
	if item.is_empty() or not bool(item.active) or float(actors[int(event.side)].health) <= 0.0: return
	var key = str(event.root_id) + ":" + str(event.side) + ":" + str(event.source_id)
	if root_activations.has(key):
		log_event(event, "CHAIN_LIMIT_REACHED", int(event.side), 0, {"reason": "same_item_same_root"})
		return
	var actor: Dictionary = actors[int(event.side)]
	if str(event.payload.get("trigger", "")) == "cooldown_ready":
		if float(actor.stamina) + 0.000001 < float(item.stamina_cost):
			var retry = maxi(1, int(round(float(_rule("stamina_retry_seconds", 0.2)) / step)))
			item.retry_tick = tick + retry
			actor.starvation_until_tick = maxi(int(actor.starvation_until_tick), tick + retry)
			item.starvation_until_tick = tick + retry
			log_event(event, "STAMINA_WAIT", int(event.side), item.stamina_cost)
			return
		actor.stamina = _number(maxf(0.0, float(actor.stamina) - float(item.stamina_cost)))
		item.progress = maxf(0.0, float(item.progress) - _cooldown(actor, item))
	root_activations[key] = true
	item_stats[_stats_key(event.side, item.instance_id)].triggers += 1
	log_event(event, "ITEM_ACTIVATED", int(event.side), 0)
	for row in event.get("rows", []):
		var child = _event(event.side, event.source_id, "effect", int(event.priority), event.payload, int(event.depth) + maxi(1, int(row.get("chain_depth_cost", 1))), event.root_id)
		child["effect"] = row
		queue.push(child)
	_emit_trigger("target_activated", int(event.side), event, {"trigger_source_id": item.instance_id})

func _emit_trigger(trigger: String, side: int, parent: Dictionary, payload: Dictionary) -> void:
	if finished or float(actors[side].health) <= 0.0: return
	var merged = parent.get("payload", {}).duplicate(true)
	merged.merge(payload, true)
	merged["trigger"] = trigger
	for id in actors[side].ordered_sources:
		var item: Dictionary = actors[side].sources[id]
		if not item.active: continue
		var rows: Array = []
		for row in _rows_for(item, trigger):
			var template = str(row.get("spatial_template_id", "none"))
			var origin_id = str(merged.get("trigger_source_id", ""))
			if trigger in ["target_activated", "attack_hit", "critical_hit", "status_applied"] and template != "none":
				if not item.relations.get(template, []).has(origin_id): continue
			if trigger == "target_activated" and template == "none" and origin_id != id: continue
			rows.append(row)
		if rows.is_empty(): continue
		var event = _event(side, id, "activate", _priority(trigger), merged, int(parent.get("depth", 0)), str(parent.root_id))
		event["rows"] = rows
		queue.push(event)

func condition(row: Dictionary, item: Dictionary, event: Dictionary) -> bool:
	var actor: Dictionary = actors[int(event.side)]
	var params = Params.parse_params(row.get("condition_params", ""))
	var effect_id = str(row.get("id", row.get("effect_type", "")))
	var count = int(item.effect_counts.get(effect_id, 0))
	var effect_params = Params.parse_params(row.get("effect_params", ""))
	var limit = int(row.get("per_combat_limit", effect_params.get("limit", effect_params.get("max_stacks", 2147483647))))
	if count >= limit: return false
	var internal = float(row.get("internal_cooldown", _trigger_default(row.get("trigger_id", ""))))
	if tick - int(item.last_effect_tick.get(effect_id, -1000000)) < int(ceil(internal / step)): return false
	if str(item.instance_id).begins_with("__passive__:"):
		if params.has("distinct_weapon_shapes"):
			var origin = source(event.side, str(event.payload.get("trigger_source_id", "")))
			var shape_id = str(origin.get("shape_id", ""))
			if not origin.get("tags", []).has("weapon") or shape_id.is_empty() or actor.weapon_shapes_seen.has(shape_id): return false
		if params.has("new_negative_status_only"):
			var status_id = str(event.payload.get("status_id", ""))
			if str(statuses.definition(status_id).get("polarity", "")) != "negative" or actor.negative_seen.has(status_id): return false
	var raw = params.get("value", 0)
	var template = str(row.get("spatial_template_id", "none"))
	var relations = item.relations.get(template, []).filter(func(id): return source(event.side, str(id)).get("active", false))
	match str(row.get("condition_id", "always")):
		"always": return true
		"source_has_tag": return item.tags.has(str(params.get("tag", raw)))
		"target_has_tag":
			var tag = str(params.get("tag", raw))
			if template != "none":
				for id in relations:
					if source(event.side, id).get("tags", []).has(tag): return true
				return false
			return item.tags.has(tag)
		"spatial_target_count": return _count_matches(relations.size(), params)
		"health_below_pct": return float(actor.health) / float(actor.max_health) < float(params.get("threshold", raw))
		"health_above_pct": return float(actor.health) / float(actor.max_health) > float(params.get("threshold", raw))
		"resource_at_least": return float(actor.get(str(params.get("resource", "armor")), 0.0)) >= float(params.get("amount", raw))
		"status_stacks_at_least": return statuses.stacks(actor, str(params.get("status_id", params.get("status", "poison")))) >= int(params.get("stacks", raw))
		"trigger_count_max": return count < int(params.get("max", raw)) if not params.has("new_negative_status_only") else true
		"build_tag_count":
			if params.has("distinct_weapon_shapes"): return true
			var tag = str(params.get("tag", ""))
			var number = 0
			for candidate in actor.sources.values():
				if int(candidate.category) == 2 and candidate.active and (tag.is_empty() or candidate.tags.has(tag)): number += 1
			return _count_matches(number, params)
		"enemy_has_status": return statuses.stacks(actors[1 - int(event.side)], str(params.get("status_id", raw))) > 0
		"overheal_positive": return float(root_contexts.get(str(event.root_id), {}).get("overheal", 0.0)) > 0.0
	return false

func targets(item: Dictionary, row: Dictionary, event: Dictionary) -> Array:
	var side = int(event.side)
	if Params.parse_params(row.get("effect_params", "")).has("repeat_pct"):
		return [{"side": int(event.payload.get("target_side", 1 - side)), "instance_id": ""}]
	var selector = str(row.get("target_selector", "self"))
	if selector == "enemy": return [{"side": 1 - side, "instance_id": ""}]
	if selector == "self": return [{"side": side, "instance_id": ""}]
	if selector == "source_item": return [{"side": side, "instance_id": str(item.instance_id)}]
	var result: Array = []
	if selector == "spatial_targets":
		for id in item.relations.get(str(row.get("spatial_template_id", "none")), []):
			var target = source(side, str(id))
			if not target.get("active", false): continue
			if str(row.get("condition_id", "")) == "target_has_tag":
				var params = Params.parse_params(row.get("condition_params", ""))
				if not target.tags.has(str(params.get("tag", params.get("value", "")))): continue
			result.append({"side": side, "instance_id": str(id)})
	return result

func damage(event: Dictionary, target_side: int, base: float, kind: String, status_id: String = "") -> void:
	var side = int(event.side)
	var attacker: Dictionary = actors[side]
	var target: Dictionary = actors[target_side]
	var item = source(side, str(event.source_id))
	var critical = false
	var amount = maxf(0.0, base)
	if status_id.is_empty():
		if kind == "physical_damage":
			critical = _roll("critical", str(event.source_id)) < _crit_chance(attacker, item)
		amount = _raw_damage(attacker, item, base, critical)
	amount = floor(amount)
	if kind == "physical_damage": amount = floor(amount * (1.0 - minf(float(_rule("damage_reduction_cap", 0.7)), statuses.value(target, "fortified"))))
	var previous_armor = float(target.armor)
	var absorbed = minf(float(target.armor), amount) if kind == "physical_damage" else 0.0
	target.armor = maxf(0.0, float(target.armor) - absorbed)
	var life_damage = floor(maxf(0.0, amount - absorbed) * (1.0 + statuses.value(target, "vulnerable")))
	var actual = minf(float(target.health), life_damage)
	target.health = _number(maxf(0.0, float(target.health) - life_damage))
	final_damage_type = status_id if not status_id.is_empty() else kind
	var stats_key = _stats_key(side, str(event.source_id))
	if item_stats.has(stats_key):
		item_stats[stats_key].damage += actual + absorbed
		item_stats[stats_key].health_damage += actual
	log_event(event, "STATUS_DAMAGE" if not status_id.is_empty() else kind.to_upper(), target_side, actual, {"armor_absorbed": absorbed, "critical": critical, "status_id": status_id})
	if kind == "physical_damage" and actual > 0.0 and statuses.value(attacker, "lifesteal") > 0.0:
		heal(event, side, actual * statuses.value(attacker, "lifesteal"), true)
	if previous_armor > 0.0 and float(target.armor) <= 0.0: _armor_broken(target, event)
	_check_death()
	if finished: return
	if kind == "physical_damage":
		_emit_trigger("attack_hit", side, event, {"trigger_source_id": event.source_id, "life_damage": actual})
		if critical: _emit_trigger("critical_hit", side, event, {"trigger_source_id": event.source_id, "life_damage": actual})
	if actual > 0.0: _emit_trigger("damage_taken", target_side, event, {"damage": actual, "trigger_source_id": event.source_id})
	_check_low_health(target, event)
	_check_boss_phase(target, event)

func heal(event: Dictionary, target_side: int, base: float, lifesteal: bool = false, scaled_stacks: bool = false) -> void:
	var actor: Dictionary = actors[target_side]
	var source_actor: Dictionary = actors[int(event.side)]
	var item = source(event.side, event.source_id)
	var power = 0.0 if lifesteal or scaled_stacks else _modifier_sum(source_actor, item, "status_power")
	var reduction = minf(0.95, fatigue_count * float(_rule("fatigue_healing_reduction_per_tick", 0.08)))
	var amount = maxf(0.0, floor(base * maxf(0.0, 1.0 + power) * (1.0 - reduction)))
	var actual = minf(maxf(0.0, float(actor.max_health) - float(actor.health)), amount)
	actor.health = _number(minf(float(actor.max_health), float(actor.health) + actual))
	actor.total_healing += actual
	var key = _stats_key(event.side, event.source_id)
	if item_stats.has(key): item_stats[key].healing += actual
	var root = root_contexts.get(str(event.root_id), {})
	root["overheal"] = amount - actual
	root_contexts[str(event.root_id)] = root
	log_event(event, "HEAL", target_side, actual, {"overheal": amount - actual, "lifesteal": lifesteal})

func gain_armor(event: Dictionary, target_side: int, amount: float) -> void:
	var actor: Dictionary = actors[target_side]
	amount = maxf(0.0, floor(amount))
	actor.armor = _number(float(actor.armor) + amount)
	actor.peak_armor = maxf(float(actor.peak_armor), float(actor.armor))
	var key = _stats_key(event.side, event.source_id)
	if item_stats.has(key): item_stats[key].armor += amount
	log_event(event, "ARMOR_GAINED", target_side, amount)
	if amount > 0.0: _emit_trigger("armor_gained", target_side, event, {"armor": amount, "trigger_source_id": event.source_id})

func gain_stamina(event: Dictionary, target_side: int, amount: float) -> void:
	var actor: Dictionary = actors[target_side]
	var previous = float(actor.stamina)
	actor.stamina = _number(clampf(previous + amount, 0.0, float(actor.stamina_max)))
	log_event(event, "STAMINA_CHANGED", target_side, float(actor.stamina) - previous)

func apply_status(event: Dictionary, target_side: int, id: String, count: int, duration: float, scale_power: bool = true) -> void:
	var actor: Dictionary = actors[int(event.side)]
	var item = source(event.side, event.source_id)
	var power = _modifier_sum(actor, item, "status_power")
	if scale_power: count = maxi(0, int(floor(count * maxf(0.0, 1.0 + power) * float(actor.status_scalar))))
	var applied = statuses.apply(actors[target_side], id, count, duration, tick, step, event.source_id, event.side)
	if int(applied.added) <= 0: return
	var key = _stats_key(event.side, event.source_id)
	if item_stats.has(key): item_stats[key].status_applied += applied.added
	var totals: Dictionary = status_totals[str(event.side)]
	var totals_row = totals.get(id, {"applied": 0, "peak": 0})
	totals_row.applied += applied.added
	totals_row.peak = maxi(int(totals_row.peak), statuses.stacks(actors[target_side], id))
	totals[id] = totals_row
	log_event(event, "STATUS_APPLIED", target_side, applied.added, {"status_id": id})
	_emit_trigger("status_applied", event.side, event, {"status_id": id, "stacks": applied.added, "target_side": target_side, "trigger_source_id": event.source_id})

func add_modifier(event: Dictionary, target: Dictionary, stat: String, value: float, duration: float) -> void:
	var actor: Dictionary = actors[int(target.side)]
	var list: Array = actor.modifiers if str(target.instance_id).is_empty() else source(target.side, target.instance_id).modifiers
	list.append({"stat": stat, "value": value, "expires": tick + maxi(1, int(ceil(duration / step))) if duration > 0.0 else -1, "source_id": str(event.source_id)})
	log_event(event, "MODIFIER_APPLIED", target.side, value, {"stat": stat, "target_instance_id": target.instance_id, "duration": duration})

func advance_cooldown(event: Dictionary, target: Dictionary, seconds: float) -> void:
	var item = source(target.side, target.instance_id)
	if item.is_empty() or float(item.cooldown) <= 0.0: return
	var key = str(event.root_id) + ":" + str(target.side) + ":" + str(target.instance_id)
	var total = float(root_advances.get(key, 0.0))
	var cap = float(_rule("cooldown_advance_cap_per_root", 1.0))
	var advanced = minf(maxf(0.0, seconds), maxf(0.0, cap - total))
	root_advances[key] = total + advanced
	item.progress = _number(float(item.progress) + advanced)
	log_event(event, "COOLDOWN_ADVANCED", target.side, advanced, {"target_instance_id": target.instance_id})
	if advanced < seconds: log_event(event, "CHAIN_LIMIT_REACHED", target.side, advanced, {"reason": "cooldown_advance_cap"})
	if float(item.progress) + 0.000001 >= _cooldown(actors[int(target.side)], item):
		var child = _event(target.side, target.instance_id, "activate", _priority("cooldown_ready"), {"trigger": "cooldown_ready"}, int(event.depth), str(event.root_id))
		child["rows"] = _rows_for(item, "cooldown_ready")
		queue.push(child)

func log_event(event: Dictionary, type: String, target_side: int, value, detail: Dictionary = {}) -> void:
	var row = {"time": _number(tick * step), "tick": tick, "event_id": str(event.get("event_id", "")), "root_event_id": str(event.get("root_id", "")),
		"source": str(event.get("source_id", "")), "source_side": int(event.get("side", 0)), "target": target_side, "target_side": target_side,
		"type": type, "event_type": type, "value": value, "depth": int(event.get("depth", 0))}
	row.merge(detail, true)
	consumed_events += 1
	event_hash.update((JSON.stringify(row, "", true, true) + "\n").to_utf8_buffer())
	full_events.append(row)
	if full_events.size() > 4000: full_events.pop_front()

func _check_death() -> void:
	if finished or actors.size() < 2: return
	if float(actors[0].health) <= 0.0 or float(actors[1].health) <= 0.0:
		finished = true
		winner_side = 1 if float(actors[0].health) <= 0.0 else 0
		defeat_reason = "simultaneous_death" if float(actors[0].health) <= 0.0 and float(actors[1].health) <= 0.0 else ("player_dead" if winner_side == 1 else "enemy_dead")
		log_event(_event(winner_side, "__character__", "death", 0), "DEATH", 1 - winner_side, 0, {"winner_side": winner_side, "reason": defeat_reason})

func _check_low_health(actor: Dictionary, event: Dictionary) -> void:
	if actor.low_health_emitted or float(actor.health) <= 0.0: return
	var threshold = float(_rule("first_low_health_threshold", 0.35))
	if float(actor.health) / float(actor.max_health) <= threshold:
		actor.low_health_emitted = true
		_emit_trigger("first_low_health", actor.side, event, {"health_pct": float(actor.health) / float(actor.max_health)})

func _mark_passive(item: Dictionary, event: Dictionary) -> void:
	var actor: Dictionary = actors[int(event.side)]
	if not str(item.instance_id).begins_with("__passive__:"): return
	var params = Params.parse_params(event.get("effect", {}).get("condition_params", ""))
	if params.has("distinct_weapon_shapes"):
		var origin = source(event.side, str(event.payload.get("trigger_source_id", "")))
		actor.weapon_shapes_seen[str(origin.get("shape_id", ""))] = true
	if params.has("new_negative_status_only"): actor.negative_seen[str(event.payload.get("status_id", ""))] = true

func _rows_for(item: Dictionary, trigger: String) -> Array:
	var result: Array = []
	for row in item.get("effects", []):
		if str(row.get("trigger_id", "")) == trigger: result.append(row)
	result.sort_custom(func(a, b):
		if int(a.get("sequence", 0)) != int(b.get("sequence", 0)): return int(a.get("sequence", 0)) < int(b.get("sequence", 0))
		return str(a.get("id", "")) < str(b.get("id", "")))
	return result

func _modifier_sum(actor: Dictionary, item: Dictionary, stat: String) -> float:
	var amount = 0.0
	for modifier in actor.modifiers + item.get("modifiers", []):
		if str(modifier.stat) == stat: amount += float(modifier.value)
	return amount

func _expire_modifiers(list: Array) -> void:
	for index in range(list.size() - 1, -1, -1):
		if int(list[index].expires) >= 0 and tick >= int(list[index].expires): list.remove_at(index)

func _cooldown(actor: Dictionary, item: Dictionary) -> float:
	return maxf(float(_rule("minimum_cooldown_seconds", 0.5)), float(item.cooldown) * maxf(0.01, 1.0 + _modifier_sum(actor, item, "cooldown_pct")))

func _crit_chance(actor: Dictionary, item: Dictionary) -> float:
	return clampf(float(actor.crit_chance) + _modifier_sum(actor, item, "crit_chance"), 0.0, float(_rule("crit_chance_cap", 0.75)))

func _raw_damage(actor: Dictionary, item: Dictionary, base: float, critical: bool) -> float:
	var amount = maxf(0.0, maxf(0.0, base) + _modifier_sum(actor, item, "damage_flat")) * float(actor.damage_scalar)
	if critical: amount *= float(actor.crit_multiplier)
	return floor(amount)

func _roll(domain: String, instance_id: String) -> float:
	var purpose = domain + ":" + instance_id
	rng_purpose_counts[purpose] = int(rng_purpose_counts.get(purpose, 0)) + 1
	rng_state = (rng_state * 48271) % 2147483647
	return float(rng_state) / 2147483647.0

func _priority(trigger) -> int:
	var row = db.get_row("trigger_templates", str(trigger)) if db != null else {}
	return int(row.get("priority", 50))

func _trigger_default(trigger) -> float:
	var row = db.get_row("trigger_templates", str(trigger)) if db != null else {}
	return float(row.get("default_internal_cooldown", 0.0))

func _rule(key: String, fallback):
	return db.value(key, fallback) if db != null else fallback

func _number(value: float) -> float: return snappedf(value, 0.000001)
func _stats_key(side: int, id: String) -> String: return id if side == 0 else "enemy:" + id

func _count_matches(count: int, params: Dictionary) -> bool:
	if params.has("max") and count > int(params.max): return false
	if params.has("equals") and count != int(params.equals): return false
	return count >= int(params.get("min", params.get("value", 1)))

func _sample(force: bool = false) -> void:
	if not timeline.is_empty() and int(timeline[-1].tick) == tick:
		if force: timeline.pop_back()
		else: return
	var states: Array = []
	for actor in actors:
		var status_data: Dictionary = {}
		for id in actor.statuses:
			var state: Dictionary = actor.statuses[id]
			status_data[id] = {"stacks": state.stacks, "cap": int(statuses.definition(id).get("stack_cap", 0)),
				"next_tick": _number(maxi(0, int(state.next_tick) - tick) * step), "remaining_duration": _number(maxi(0, int(state.expires) - tick) * step) if int(state.expires) >= 0 else -1}
		states.append({"health": _number(actor.health), "max_health": _number(actor.max_health), "armor": _number(actor.armor), "stamina": _number(actor.stamina), "stamina_max": actor.stamina_max, "statuses": status_data, "phase": actor.phase})
	timeline.append({"time": _number(tick * step), "tick": tick, "sides": states})
	if timeline.size() > 500: timeline.remove_at(1)

func _key_events() -> Array:
	var selected: Array = []
	for event in full_events:
		if event.type in ["DEATH", "BOSS_PHASE", "FATIGUE_START"]: selected.append(event)
	if selected.size() > 3: return selected.slice(selected.size() - 3)
	return selected

func _schedule_boss(actor: Dictionary) -> void:
	if actor.phases.is_empty(): return
	if int(actor.phase_due) >= 0 and tick >= int(actor.phase_due):
		for phase in actor.phases:
			if int(phase.phase) == int(actor.pending_phase): queue.push(_event(actor.side, "__boss__", "boss_phase", 6, phase))
		actor.phase_due = -1
	if int(actor.boss_next_tick) >= 0 and tick >= int(actor.boss_next_tick):
		actor.boss_next_tick = tick + maxi(1, int(round(float(actor.boss_params.get("interval", 5.0)) / step)))
		queue.push(_event(actor.side, "__boss__", "boss_rule", _priority("interval")))

func _check_boss_phase(actor: Dictionary, event: Dictionary) -> void:
	if actor.phases.is_empty() or int(actor.pending_phase) > int(actor.phase) or float(actor.health) <= 0.0: return
	for phase in actor.phases:
		if int(phase.phase) > int(actor.phase) and float(actor.health) / float(actor.max_health) <= float(phase.health_threshold_pct):
			actor.pending_phase = int(phase.phase)
			actor.phase_due = tick + maxi(1, int(round(float(phase.get("telegraph_seconds", 0.0)) / step)))
			log_event(event, "BOSS_PHASE_TELEGRAPH", actor.side, phase.phase, {"telegraph_seconds": phase.get("telegraph_seconds", 0.0)})
			break

func _set_phase(actor: Dictionary, phase: Dictionary) -> void:
	actor.phase = int(phase.phase)
	actor.pending_phase = int(phase.phase)
	actor.boss_params = Params.parse_params(phase.get("effect_params", ""))
	actor.boss_enraged = false
	actor.boss_next_tick = tick + maxi(1, int(round(float(actor.boss_params.get("interval", 5.0)) / step)))
	for id in actor.ordered_sources:
		var item: Dictionary = actor.sources[id]
		if not item.active and int(item.get("phase", 1)) <= int(actor.phase):
			item.active = true
			item.progress = 0.0
			var rows = _rows_for(item, "combat_start")
			if not rows.is_empty():
				var event = _event(actor.side, id, "activate", 10)
				event["rows"] = rows
				queue.push(event)
	if actor.boss_params.has("cooldown_pct"):
		actor.modifiers = actor.modifiers.filter(func(v): return str(v.get("source_id", "")) != "__boss_phase__")
		actor.modifiers.append({"stat": "cooldown_pct", "value": float(actor.boss_params.cooldown_pct), "expires": -1, "source_id": "__boss_phase__"})
	if tick > 0: log_event(_event(actor.side, "__boss__", "boss_phase", 6), "BOSS_PHASE", actor.side, actor.phase)

func _boss_rule(event: Dictionary) -> void:
	var actor: Dictionary = actors[int(event.side)]
	var params: Dictionary = actor.boss_params
	if params.has("armor_gain"): gain_armor(event, event.side, float(params.armor_gain))
	if params.has("burn"): apply_status(event, 1 - int(event.side), "burn", int(params.burn), 0.0)
	if params.has("heal"): heal(event, event.side, float(params.heal))
	if params.has("front_damage_flat"):
		var weapons: Array = []
		for id in actor.ordered_sources:
			var item: Dictionary = actor.sources[id]
			if item.active and item.tags.has("weapon"): weapons.append(item)
		weapons.sort_custom(func(a, b):
			if int(a.get("x", 0)) != int(b.get("x", 0)): return int(a.get("x", 0)) < int(b.get("x", 0))
			return str(a.instance_id) < str(b.instance_id))
		if not weapons.is_empty():
			var item: Dictionary = weapons[0]
			var target_ids = item.relations.get("front_3", []).filter(func(id):
				var candidate = source(event.side, str(id))
				return candidate.get("active", false) and candidate.get("tags", []).has("weapon"))
			if target_ids.is_empty(): target_ids = [item.instance_id]
			for target_id in target_ids:
				var target_item = source(event.side, str(target_id))
				target_item.modifiers = target_item.modifiers.filter(func(v): return str(v.get("source_id", "")) != "__boss__")
				add_modifier(event, {"side": event.side, "instance_id": target_id}, "damage_flat", float(params.front_damage_flat), float(params.get("interval", 5.0)))
	_check_death()

func _armor_broken(actor: Dictionary, event: Dictionary) -> void:
	if str(actor.snapshot.get("boss_rule_id", "")) == "armor_break_frenzy" and not actor.boss_enraged and actor.boss_params.has("damage_flat"):
		actor.boss_enraged = true
		actor.modifiers.append({"stat": "damage_flat", "value": float(actor.boss_params.damage_flat), "expires": -1, "source_id": "__boss_frenzy__"})
		log_event(event, "BOSS_FRENZY", actor.side, actor.boss_params.damage_flat)
