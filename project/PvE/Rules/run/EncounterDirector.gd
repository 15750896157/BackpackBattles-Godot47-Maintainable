class_name EncounterDirector
extends RefCounted

var db

func _init(content = null):
	db = content

func generate_act(run: Dictionary) -> Dictionary:
	var rng = DeterministicRNG.new(int(run.rng.route))
	var plan: Array = []
	var fallback_plan: Array = []
	var act_id = "act_" + str(int(run.act))
	for step in range(1, 6):
		var template: Dictionary = {}
		for row in db.rows("route_templates"):
			if row.act_id == act_id and int(row.step) == step: template = row
		if template.is_empty(): return {"ok": false, "error": "route_template_missing"}
		var available: Array = db.list_values(template.allowed_nodes)
		var picked: Array = []
		var required: Array = db.list_values(template.required_nodes)
		var eligible_required: Array = []
		for id in required:
			if id in available: eligible_required.append(id)
		if not eligible_required.is_empty(): picked.append(rng.choose(eligible_required))
		var count = int(template.candidate_count_min)
		if int(template.candidate_count_max) > count:
			count += rng.next_int() % (int(template.candidate_count_max) - count + 1)
		# Guarantee a combat option wherever non-combat choices can later be filtered.
		if "normal_combat" in available and "normal_combat" not in picked and picked.size() < count:
			picked.append("normal_combat")
		while picked.size() < count:
			var remainder: Array = []
			for id in available:
				if id not in picked: remainder.append(id)
			if remainder.is_empty(): break
			picked.append(rng.choose(remainder))
		var candidates: Array = []
		for type in picked:
			var card = make_card(run, type, rng, step)
			if str(type).ends_with("combat") and str(card.enemy_id).is_empty(): return {"ok": false, "error": "encounter_pool_empty"}
			card["step"] = step
			card["candidate_id"] = str(int(run.act)) + "_" + str(step) + "_" + str(candidates.size())
			candidates.append(card)
		plan.append(candidates)
		var fallbacks: Array = []
		for type in available:
			if str(type).ends_with("combat") and type not in picked:
				var card = make_card(run, type, rng, step)
				card["step"] = step
				card["candidate_id"] = str(int(run.act)) + "_" + str(step) + "_fallback_" + str(fallbacks.size())
				fallbacks.append(card)
		fallback_plan.append(fallbacks)
	run["route_plan"] = plan
	run["route_fallbacks"] = fallback_plan
	run.rng["route"] = rng.state
	return {"ok": true, "error": "", "plan": plan.duplicate(true)}

func make_card(run: Dictionary, type: String, rng: DeterministicRNG, planned_step: int = -1) -> Dictionary:
	var node = db.get_row("node_templates", type)
	var card = {"act": int(run.act), "type": type, "name_key": node.get("name_key", ""), "enemy_id": "", "boss_id": "", "affix_id": "", "affix_ids": [], "event_id": "", "reward_table_id": node.get("reward_table_id", "reward_none")}
	if type == "boss":
		for row in db.rows("bosses"):
			if row.act_id == "act_" + str(int(run.act)): card.boss_id = row.id
	elif type.ends_with("combat"):
		var template = db.get_row("encounter_templates", "act_" + str(int(run.act)) + "_" + type.trim_suffix("_combat"))
		var pool: Array = _enemy_pool(run, type, planned_step)
		if not pool.is_empty(): card.enemy_id = rng.choose(pool)
		var affixes: Array = db.list_values(template.get("affix_pool", ""))
		if not affixes.is_empty():
			card.affix_id = rng.choose(affixes)
			card.affix_ids.append(card.affix_id)
		var difficulty = db.get_row("difficulty_levels", str(run.get("difficulty_id", "standard")))
		for modifier in db.rows("challenge_modifiers"):
			if str(modifier.rule_type) != "elite_affix_count" or type != "elite_combat" or int(modifier.challenge_level) > int(difficulty.get("challenge_modifier_count", 0)): continue
			var params = db.parse_params(modifier.params)
			if int(run.act) < int(params.get("act_min", 1)): continue
			var remainder = affixes.filter(func(id): return id not in card.affix_ids)
			for _extra in int(params.get("extra", 0)):
				if remainder.is_empty(): break
				var selected = rng.choose(remainder)
				card.affix_ids.append(selected)
				remainder.erase(selected)
		card["repeat_limit"] = int(template.get("repeat_limit", 2))
	elif type == "event":
		var events: Array = []
		var weights: Array = []
		for row in db.rows("events"):
			if int(row.act_min) <= int(run.act) and int(row.act_max) >= int(run.act):
				events.append(row.id)
				weights.append(float(row.weight))
		if not events.is_empty(): card.event_id = rng.weighted(events, weights)
	return card

func candidates(run: Dictionary) -> Array:
	if not run.has("route_plan") or int(run.step) > run.route_plan.size(): return []
	var list: Array = run.route_plan[int(run.step) - 1].duplicate(true)
	var previous: String = ""
	if not run.completed_nodes.is_empty(): previous = str(run.completed_nodes.back().type)
	var filtered: Array = []
	for card in list:
		if not is_card_allowed(run, card): continue
		if previous in ["merchant", "rest", "event"] and card.type in ["merchant", "rest", "event"]: continue
		if card.type == "event":
			var event = db.get_row("events", card.event_id)
			if bool(event.get("once_per_run", false)) and card.event_id in run.get("events_seen", []):
				card = card.duplicate(true)
				var replacements: Array = []
				for row in db.rows("events"):
					if int(row.act_min) <= int(run.act) and int(row.act_max) >= int(run.act) and row.id not in run.get("events_seen", []): replacements.append(row.id)
				if replacements.is_empty(): continue
				card.event_id = replacements[0]
		filtered.append(finalize_card(run, card))
	if int(run.step) < 5 and filtered.size() < 2:
		var fallback_lists: Array = run.get("route_fallbacks", [])
		if int(run.step) <= fallback_lists.size():
			for card in fallback_lists[int(run.step) - 1]:
				var duplicate = false
				for existing in filtered:
					if existing.type == card.type: duplicate = true
				if not duplicate: filtered.append(finalize_card(run, card))
				if filtered.size() >= 2: break
	return filtered

func is_card_allowed(run: Dictionary, card: Dictionary) -> bool:
	if str(card.get("type", "")) not in ["merchant", "rest", "event"]: return true
	var used = 0
	# Older saves did not store act on cards. The last completed Boss still
	# provides an unambiguous chapter boundary without changing those saves.
	for index in range(run.get("completed_nodes", []).size() - 1, -1, -1):
		var node: Dictionary = run.completed_nodes[index]
		if str(node.get("type", "")) == "boss": break
		if node.has("act") and int(node.act) != int(run.act): break
		if str(node.get("type", "")) in ["merchant", "rest", "event"]: used += 1
	return used < int(db.value("max_noncombat_nodes_per_act", 1))

func finalize_card(run: Dictionary, selected: Dictionary) -> Dictionary:
	var card = selected.duplicate(true)
	if not card.enemy_id.is_empty():
		var counts: Dictionary = {}
		for previous in run.completed_nodes:
			var id = str(previous.get("enemy_id", ""))
			counts[id] = int(counts.get(id, 0)) + 1
		var eligible = _enemy_pool(run, str(card.type), int(card.get("step", run.get("step", 1))))
		var previous_id = str(run.completed_nodes.back().get("enemy_id", "")) if not run.completed_nodes.is_empty() else ""
		if card.enemy_id not in eligible or card.enemy_id == previous_id or int(counts.get(card.enemy_id, 0)) > 0:
			for id in eligible:
				# A named snapshot is a single numeric variant. Reuse another authored
				# variant rather than silently repeat that exact build at the same tier.
				if id != previous_id and int(counts.get(id, 0)) == 0:
					card.enemy_id = id
					break
	return card

func _enemy_pool(run: Dictionary, type: String, planned_step: int = -1) -> Array:
	var template = db.get_row("encounter_templates", "act_" + str(int(run.act)) + "_" + type.trim_suffix("_combat"))
	var difficulty = db.get_row("difficulty_levels", str(run.get("difficulty_id", "standard")))
	var order = int(difficulty.get("sort_order", 1))
	var loadout = db.get_row("character_loadouts", str(run.get("loadout_id", "")))
	var archetype = db.get_row("character_archetypes", str(loadout.get("archetype_hint", "")))
	var counters = db.list_values(archetype.get("counter_tags", ""))
	var step_number = int(run.get("step", 1)) if planned_step < 0 else planned_step
	var pool: Array = []
	for id in db.list_values(template.get("enemy_build_pool", "")):
		var row = db.get_row("enemy_builds", str(id))
		if row.is_empty() or str(row.get("act_id", "")) != "act_" + str(int(run.act)): continue
		var minimum = db.get_row("difficulty_levels", str(row.get("difficulty_min", "tutorial")))
		var maximum = db.get_row("difficulty_levels", str(row.get("difficulty_max", "challenge_5")))
		if order < int(minimum.get("sort_order", 0)) or order > int(maximum.get("sort_order", 7)): continue
		if int(run.act) == 1 and step_number <= 2:
			var threats = db.list_values(row.get("threat_tags", ""))
			if counters.any(func(tag): return tag in threats): continue
		pool.append(id)
	return pool
