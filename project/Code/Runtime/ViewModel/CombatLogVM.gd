extends ViewModel
## The event page exposes only events reached by the current playback.
const PAGE_SIZE := 6
var _flow: GameFlow
var _rules
var _translate: Callable
var _effect_text: Callable

func _init(flow: GameFlow, rules, translate: Callable, effect_text: Callable) -> void:
	_flow = flow
	_rules = rules
	_translate = translate
	_effect_text = effect_text

func snapshot() -> Dictionary:
	return {"events": events_page(0), "statistics": statistics()}

func _result() -> Dictionary:
	if not _flow.combat_result.is_empty():
		return _flow.combat_result
	if not _flow.run.is_empty():
		if not _flow.run.get("last_combat_result", {}).is_empty():
			return _flow.run.last_combat_result
		if not _flow.run.logs.is_empty():
			return _flow.run.logs.back()
	return {}

func events_page(requested_page: int) -> Dictionary:
	var result := _result()
	var events: Array = result.get("full_events", [])
	if _flow.screen_state == "COMBAT_RUNNING":
		var playback_time: float = _flow.playback_time
		events = events.filter(func(event): return float(event.get("time", 0)) <= playback_time)
	var pages := maxi(1, ceili(events.size() / float(PAGE_SIZE)))
	var page := clampi(requested_page, 0, pages - 1)
	var rows: Array[Dictionary] = []
	for event in events.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE):
		rows.append({"text": event_text(event, result), "time": float(event.get("time", 0))})
	return {"rows": rows, "page": page, "pages": pages}

func statistics() -> Array[Dictionary]:
	var result := _result()
	var sides: Array[Dictionary] = []
	for side in 2:
		var entries: Array = result.get("item_stats_by_instance_id", {}).values().filter(func(data): return int(data.get("side", -1)) == side)
		entries.sort_custom(func(a, b): return _contribution(a) > _contribution(b))
		var items: Array[String] = []
		var sums := Vector3.ZERO
		for data in entries:
			var name := _combat_source_label({"source": data.get("instance_id", ""), "source_side": side}, result)
			sums += Vector3(float(data.get("damage", 0)),float(data.get("healing", 0)),float(data.get("armor", 0)))
			items.append("%s · %s %.1f · %s %.1f · %s %.1f · %s %d" % [
				name, _translate.call("native.damage"), float(data.get("damage", 0)),
				_translate.call("native.healing"), float(data.get("healing", 0)),
				_translate.call("native.armor"), float(data.get("armor", 0)),
				_translate.call("native.triggers"), int(data.get("triggers", 0))])
		var totals: Dictionary = result.get("status_totals", {}).get(str(side), result.get("status_totals", {}).get(side, {}))
		var statuses: Array[Dictionary] = []
		for status in _flow.db.rows("statuses"):
			var id := str(status.id)
			if not totals.has(id):
				continue
			var values: Dictionary = totals[id]
			var applied := int(values.get("applied", 0))
			var peak := int(values.get("peak", 0))
			statuses.append({
				"text": _translate.call("native.status_totals_row", {"status": _combat_status_name(id), "applied": applied, "peak": peak}),
				"meta": {"side": side, "status_id": id, "applied": applied, "peak": peak},
			})
		var starvation = result.get("stamina_starvation_time", {})
		var stamina_text := ""
		if starvation is Dictionary:
			stamina_text = _translate.call("native.starvation", {"seconds": snappedf(float(starvation.get(str(side), starvation.get(side, 0))), 0.1)})
		elif starvation is Array and side < starvation.size():
			stamina_text = _translate.call("native.starvation", {"seconds": snappedf(float(starvation[side]), 0.1)})
		sides.append({
			"heading": _translate.call("native.player_side" if side == 0 else "native.enemy_side"),
			"summary": "%s %.1f  ·  %s %.1f  ·  %s %.1f" % [
				_translate.call("native.damage"),sums.x,_translate.call("native.healing"),sums.y,_translate.call("native.armor"),sums.z],
			"items": items, "statuses": statuses, "has_totals": not totals.is_empty(),
			"totals_heading": _translate.call("native.status_totals_heading"), "stamina": stamina_text,
		})
	return sides

func _contribution(row: Dictionary) -> float:
	return float(row.get("damage", 0)) + float(row.get("healing", 0)) + float(row.get("armor", 0))

func _combat_status_name(id: String) -> String:
	if id.is_empty() or id == "negative": return _translate.call("native.negative_statuses")
	return _rules.term("statuses", id, TranslationServer.get_locale())

func _combat_definition_name(id: String) -> String:
	for character in _flow.db.rows("characters"):
		if str(character.passive_id) == id: return _translate.call(character.name_key) + " · " + _translate.call("native.passive")
	for table in ["items", "bags", "characters", "encounter_affixes", "statuses", "bosses"]:
		var row = _flow.db.get_row(table, id)
		if row.has("name_key"): return _translate.call(row.name_key)
	for boss in _flow.db.rows("bosses"):
		if str(boss.persistent_rule_id) == id: return _translate.call(boss.name_key)
	return ""

func _combat_source_label(event: Dictionary, result: Dictionary) -> String:
	var source = str(event.get("source", ""))
	var side = int(event.get("source_side", 0))
	if source == "__fatigue__": return _translate.call("native.fatigue_source")
	if source == "__character__": return _translate.call("native.character_source")
	for data in result.get("item_stats_by_instance_id", {}).values():
		if int(data.get("side", -1)) == side and str(data.get("instance_id", "")) == source:
			var name = _combat_definition_name(str(data.get("def_id", "")))
			if not name.is_empty(): return name
	if source.begins_with("__bag__:"):
		var uid = source.trim_prefix("__bag__:").rsplit(":", false, 1)[0]
		var checkpoint = _flow.run.get("combat_checkpoint", {})
		for bag in checkpoint.get("player" if side == 0 else "enemy", {}).get("bags", []):
			if str(bag.get("instance_id", bag.get("uid", ""))) == uid:
				var name = _combat_definition_name(str(bag.get("def_id", bag.get("definition_id", ""))))
				if not name.is_empty(): return name
		return _translate.call("native.bag_effect")
	if source.begins_with("__affix__:") or source.begins_with("__passive__:"):
		var name = _combat_definition_name(source.get_slice(":", 1))
		if not name.is_empty(): return name
	if source.begins_with("__boss"):
		var node = result.get("node", _flow.run.get("current_node", {}))
		var name = _combat_definition_name(str(node.get("boss_id", "")))
		return name if not name.is_empty() else _translate.call("native.boss_rule")
	var definition = _combat_definition_name(source)
	return definition if not definition.is_empty() else _translate.call("native.system_source")

func _combat_number(value) -> String:
	return str(snappedf(float(value), 0.001)) if value is int or value is float else ""

func event_text(event: Dictionary, result: Dictionary = {}) -> String:
	if result.is_empty(): result = _result()
	var kind = str(event.get("type", ""))
	var translated = _translate.call("native.event_" + kind)
	if translated.begins_with("native.event_"): translated = _translate.call("native.battle_log")
	var source_side = int(event.get("source_side", 0))
	var target_side = int(event.get("target_side", source_side))
	var source = _translate.call("native.player_side" if source_side == 0 else "native.enemy_side") + " · " + _combat_source_label(event, result)
	var target = _translate.call("native.both_sides") if target_side < 0 else _translate.call("native.player_side" if target_side == 0 else "native.enemy_side")
	if not str(event.get("target_instance_id", "")).is_empty(): target += " · " + _combat_source_label({"source": event.target_instance_id, "source_side": target_side}, result)
	var details: Array[String] = []
	if event.has("status_id"): details.append(_combat_status_name(str(event.status_id)))
	if event.has("stat"):
		var stat = str(event.stat)
		details.append(_translate.call("native.stat_" + stat) if _translate.call("native.stat_" + stat) != "native.stat_" + stat else _translate.call("native.modifier"))
		if stat in ["cooldown_pct", "crit_chance", "status_power"]: details.append(_combat_number(float(event.get("value", 0)) * 100.0) + "%")
		else: details.append(_combat_number(event.get("value", 0)))
	elif event.has("value"): details.append(_combat_number(event.value))
	if float(event.get("armor_absorbed", 0)) > 0.0: details.append(_translate.call("native.armor_absorbed", {"amount": _combat_number(event.armor_absorbed)}))
	if bool(event.get("critical", false)): details.append(_translate.call("native.critical"))
	if float(event.get("duration", 0)) > 0.0: details.append(_translate.call("native.duration_seconds", {"seconds": _combat_number(event.duration)}))
	if event.has("telegraph_seconds"): details.append(_translate.call("native.duration_seconds", {"seconds": _combat_number(event.telegraph_seconds)}))
	if kind == "RUN_EFFECT": details.append(_effect_text.call(str(event.get("effect_type", "")), {"amount": event.get("value", 0), "count": event.get("value", 0)}))
	if event.has("reason"):
		var reason = _translate.call("native.reason_" + str(event.reason))
		if not reason.begins_with("native.reason_"): details.append(reason)
	return "%.2f s · %s → %s · %s · %s" % [float(event.get("time", 0)), source, target, translated, " · ".join(details)]
