extends SceneTree

# Automated player decisions, never changes production run values directly.
var db
var reports: Array = []
var started: int
var errors: Array = []
var serial = 0

class SimulationSaves:
	extends RefCounted
	var base_path = "user://campaign_verification/"
	var last_error = ""
	func load_save(_kind: String) -> Dictionary: return {"ok": false, "error": "missing", "data": {}}
	func exists(_kind: String) -> bool: return false
	func save(kind: String, value: Dictionary) -> bool:
		if kind == "run":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path))
			var progress = FileAccess.open(base_path + "state.json", FileAccess.WRITE)
			if progress != null:
				progress.store_string(JSON.stringify({"state": value.state, "act": value.act, "step": value.step, "health": value.health, "gold": value.gold, "items": value.build.items.size()}))
				progress.close()
		return true

func _init():
	call_deferred("_run")

func _run():
	db = ContentDB.new()
	started = Time.get_ticks_msec()
	var cases = [
		{"character": "armorer", "difficulty": "tutorial", "seed": 67731},
		{"character": "alchemist", "difficulty": "tutorial", "seed": 12345},
		{"character": "armorer", "difficulty": "standard", "seed": 18421},
		{"character": "alchemist", "difficulty": "standard", "seed": 31337}]
	for specification in cases:
		_play(specification)
	# At most four additional fixed seeds, only when no complete run was observed.
	if not reports.any(func(report): return report.clear):
		for specification in [{"character": "armorer", "difficulty": "tutorial", "seed": 555}, {"character": "alchemist", "difficulty": "tutorial", "seed": 930}, {"character": "armorer", "difficulty": "standard", "seed": 20261014}, {"character": "alchemist", "difficulty": "standard", "seed": 429}]:
			if Time.get_ticks_msec() - started >= 120000 or reports.any(func(report): return report.clear): break
			_play(specification)
	var result = {"content_version": db.content_version, "content_sha256": db.content_sha256, "runtime_seconds": float(Time.get_ticks_msec() - started) / 1000.0, "run_count": reports.size(), "clear_count": reports.filter(func(report): return report.clear).size(), "errors": errors, "runs": reports}
	print("CAMPAIGN_SIMULATION " + JSON.stringify(result))
	var evidence = FileAccess.open("user://campaign_verification/evidence.json", FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify(result, "\t"))
		evidence.close()
	quit(0 if errors.is_empty() else 1)

func _play(specification: Dictionary):
	serial += 1
	var directory = "user://campaign_verification/%d_%s_%s_%d/" % [Time.get_unix_time_from_system(), specification.character, specification.difficulty, specification.seed]
	var memory = SimulationSaves.new()
	memory.base_path = directory
	var flow = GameFlow.new(db, memory)
	var loadout = "armorer_blades" if specification.character == "armorer" else "alchemist_toxin"
	var setup = flow.new_run(specification.character, loadout, specification.difficulty, int(specification.seed), true)
	var report = {"character": specification.character, "difficulty": specification.difficulty, "seed": specification.seed, "clear": false, "start_gold": flow.run.get("gold", 0), "start_health": flow.run.get("health", 0), "max_act": 1, "battles": [], "bosses_defeated": [], "nodes": [], "purchases": [], "crafts": [], "refreshes": 0, "stop_reason": "", "directory": directory}
	if not setup.ok:
		report.stop_reason = str(setup.error)
		errors.append(report.stop_reason)
		reports.append(report)
		return
	flow.skip_tutorial()
	var steps = 0
	while flow.screen_state != "RUN_RESULT" and steps < 120:
		steps += 1
		report.max_act = maxi(int(report.max_act), int(flow.run.act))
		var result = {"ok": true, "error": ""}
		match flow.screen_state:
			"ROUTE_SELECT":
				var index = _route(flow)
				result = flow.choose_route(index)
				if result.ok: report.nodes.append({"act": flow.run.act, "step": flow.run.step, "node": flow.run.current_node.duplicate(true)})
			"SHOP_PREPARE":
				_resolve_pending(flow)
				_shop(flow, report)
				_craft(flow, report)
				_restore(flow)
				_position_supports(flow)
				result = flow.start_combat()
			"COMBAT_RUNNING":
				if not flow.combat_result.get("ok", false):
					result = {"ok": false, "error": flow.combat_result.get("error", "combat_failed")}
				else:
					report.battles.append({"act": flow.run.act, "step": flow.run.step, "enemy_id": flow.run.current_node.get("enemy_id", ""), "boss_id": flow.run.current_node.get("boss_id", ""), "winner_side": flow.combat_result.winner_side, "duration": flow.combat_result.elapsed_time, "health_before": flow.run.health, "health_after": flow.combat_result.player_remaining_health, "enemy_health_after": flow.combat_result.enemy_remaining_health, "defeat_reason": flow.combat_result.get("defeat_reason", ""), "digest": flow.combat_result.replay_digest, "items": flow.run.build.items.size(), "gold": flow.run.gold})
					flow.advance_combat(float(flow.combat_result.elapsed_time) + 1.0)
			"COMBAT_RESULT":
				if int(flow.combat_result.winner_side) == 0 and flow.run.current_node.type == "boss": report.bosses_defeated.append(str(flow.run.current_node.boss_id))
				result = flow.confirm_combat()
			"REWARD_SELECT":
				if not bool(flow.run.get("reward_selected", false)):
					result = _reward(flow)
				if result.ok:
					_resolve_pending(flow)
					result = flow.complete_node()
			"EVENT", "REST": result = _event(flow)
			"ACT_RESULT": result = flow.next_act()
			_: result = {"ok": false, "error": "unexpected_state_" + flow.screen_state}
		if not result.ok:
			report.stop_reason = str(result.error)
			errors.append("%s/%s/%d: %s" % [specification.character, specification.difficulty, specification.seed, result.error])
			break
	if flow.screen_state == "RUN_RESULT":
		report.clear = bool(flow.run.get("profile_result_recorded", false)) and report.bosses_defeated.size() == 3
		report.stop_reason = "clear" if report.clear else "real_combat_defeat"
	elif steps >= 120:
		report.stop_reason = "state_limit"
		errors.append("state_limit")
	report["final_health"] = flow.run.health
	report["final_gold"] = flow.run.gold
	report["final_items"] = flow.run.build.items.duplicate(true)
	report["completed_nodes"] = flow.run.completed_nodes.size()
	reports.append(report)
	print("CAMPAIGN_RUN " + JSON.stringify({"character": report.character, "difficulty": report.difficulty, "seed": report.seed, "clear": report.clear, "max_act": report.max_act, "bosses": report.bosses_defeated, "battles": report.battles.size(), "stop_reason": report.stop_reason, "health": report.final_health}))
	var checkpoint = FileAccess.open("user://campaign_verification/progress.json", FileAccess.WRITE)
	if checkpoint != null:
		checkpoint.store_string(JSON.stringify(reports))
		checkpoint.close()

func _route(flow) -> int:
	var best = -INF
	var index = 0
	for i in range(flow.run.route_candidates.size()):
		var card = flow.run.route_candidates[i]
		var score = 0.0
		match str(card.type):
			"rest": score = 80.0 if float(flow.run.health) / float(flow.run.max_health) < 0.8 else 25.0
			"event": score = 50.0
			"merchant": score = 35.0 if int(flow.run.gold) >= 5 else 5.0
			"normal_combat":
				var enemy = db.get_row("enemy_builds", str(card.enemy_id))
				score = 40.0 - float(enemy.get("max_health", 80)) * 0.12
			"danger_combat": score = 5.0
			"elite_combat": score = -5.0
			"boss": score = 1.0
		if score > best:
			best = score
			index = i
	return index

func _value(id: String, flow) -> float:
	var item = db.get_row("items", id)
	if item.is_empty():
		var bag = db.get_row("bags", id)
		if bag.is_empty(): return 0.0
		var valid = flow.placement.validate(flow.run.build)
		var free = valid.get("valid_cells", []).size() - valid.get("item_occupancy", {}).size()
		return 14.0 if free <= 2 else 1.0
	var value = 0.1
	var cooldown = maxf(1.0, float(item.cooldown))
	var cell_count = maxi(1, db.shape(str(item.shape_id)).size())
	for effect in db.rows("item_effects"):
		if effect.item_id != id: continue
		var params = SnapshotBuilder.parse_params(effect.effect_params)
		var raw_value = str(params.get("value", "0"))
		var amount = float(raw_value)
		var status = ""
		if raw_value.contains(":"):
			var fields = raw_value.split(":", true, 1)
			status = fields[0]
			amount = float(fields[1])
		match str(effect.effect_type):
			"physical_damage": value += amount / cooldown * 2.0
			"true_damage": value += amount / cooldown * 2.5
			"apply_status":
				var kind = status
				if kind in ["poison", "burn"]: value += amount / cooldown * 10.0
				elif kind == "regeneration": value += amount / cooldown * 8.0
				else: value += amount / cooldown * 2.0
			"gain_armor": value += amount / cooldown * 3.5
			"heal": value += amount / cooldown * 5.0
			"modify_damage_flat": value += amount * minf(4.0, float(flow.run.build.items.size()))
			"modify_cooldown_pct": value += absf(amount) * 35.0
			"advance_cooldown": value += amount * 6.0
			"gain_stamina": value += amount / cooldown
			"gain_gold": value += amount * 1.5
			"free_refresh": value += 1.5
	return value / sqrt(float(cell_count))

func _shop(flow, report: Dictionary):
	var refreshes = 0
	for cycle in range(12):
		var best = -1
		var best_score = 0.0
		for index in range(flow.run.shop.slots.size()):
			var slot = flow.run.shop.slots[index]
			if bool(slot.sold) or int(slot.price) > int(flow.run.gold): continue
			var value = _value(str(slot.definition_id), flow)
			var score = value / maxf(1.0, float(slot.price))
			# A bounded player build keeps this smoke campaign inexpensive. Avoid
			# filling every grid cell with low-value trigger listeners.
			if flow.run.build.items.size() >= 12 and slot.kind != "bag":
				continue
			var test = flow.run.duplicate(true)
			var trial = flow.economy.buy(test, index)
			if not trial.ok or (trial.get("stored", false) and value < 5.0): continue
			if score > best_score:
				best_score = score
				best = index
		if best >= 0 and best_score >= 0.65:
			var id = str(flow.run.shop.slots[best].definition_id)
			if flow.buy(best).ok:
				report.purchases.append({"visit": flow.run.visit, "act": flow.run.act, "id": id})
				_restore(flow)
				continue
		var cost = flow.economy.refresh_cost(flow.run)
		if refreshes < 3 and (cost == 0 or int(flow.run.gold) >= cost + 3):
			if flow.refresh_shop().ok:
				refreshes += 1
				report.refreshes += 1
				continue
		break

func _restore(flow):
	for stored in flow.run.build.storage.duplicate(true):
		if flow.edit("restore", str(stored.uid)).ok: continue
		var weakest: Dictionary = {}
		var minimum = INF
		for item in flow.run.build.items:
			var value = _value(str(item.definition_id), flow)
			if value < minimum:
				minimum = value
				weakest = item
		if not weakest.is_empty() and _value(str(stored.definition_id), flow) > minimum * 1.3:
			var test = flow.run.build.duplicate(true)
			if flow.placement.remove(test, str(weakest.uid)).ok and flow.placement.restore(test, str(stored.uid)).ok:
				flow.sell(str(weakest.uid), true)
				flow.edit("restore", str(stored.uid))

func _position_supports(flow):
	# Choose legal locations with the most live spatial links, using previews only.
	var examined = 0
	for item in flow.run.build.items.duplicate(true):
		var templates: Array = []
		for effect in db.rows("item_effects"):
			if effect.item_id == item.definition_id and (str(effect.target_selector) == "spatial_targets" or str(effect.condition_id) == "spatial_target_count") and str(effect.spatial_template_id) not in ["none", "global_same_tag"]:
				templates.append(str(effect.spatial_template_id))
		if templates.is_empty(): continue
		examined += 1
		if examined > 3: break
		var current = 0
		for template in templates: current += flow.spatial.targets(flow.run.build, str(item.uid), template).size()
		if current >= 2: continue
		var best = 0
		var location: Dictionary = {}
		for rotation in flow.placement.rotations(item):
			if best >= 2: break
			for y in range(7):
				if best >= 2: break
				for x in range(9):
					if best >= 2: break
					var preview = flow.placement.preview(flow.run.build, item, x, y, rotation)
					if not preview.ok: continue
					var score = 0
					for template in templates: score += flow.spatial.targets(preview.build, str(item.uid), template).size()
					if score > best:
						best = score
						location = {"x": x, "y": y, "rotation": rotation}
		if not location.is_empty(): flow.edit("move", str(item.uid), location)

func _craft(flow, report: Dictionary):
	for recipe in flow.crafting.candidates(flow.run.build, int(flow.run.act)):
		var value = _value(str(recipe.result_item_id), flow)
		var material_value = 0.0
		for uid in recipe.material_uids:
			material_value += _value(str(flow.placement.find(flow.run.build, str(uid)).entry.definition_id), flow)
		if value < material_value * 0.7: continue
		var preview = flow.crafting.preview(flow.run, str(recipe.recipe_id))
		if preview.ok and not preview.pending and flow.craft(str(recipe.recipe_id)).ok:
			report.crafts.append(str(recipe.recipe_id))
			break

func _reward(flow) -> Dictionary:
	var best = -INF
	var selected = -1
	for index in range(flow.run.reward_choices.size()):
		var reward = flow.run.reward_choices[index]
		var value = 0.0
		match str(reward.type):
			"item_pool", "bag_pool": value = _value(str(reward.definition_id), flow) * 2.0
			"gold": value = float(reward.params.get("amount", 0)) * 2.0
			"heal_pct": value = minf(float(flow.run.max_health) - float(flow.run.health), float(flow.run.max_health) * float(reward.params.get("amount", 0))) * 0.75
			"upgrade_item": value = 12.0
			"recipe_discovery": value = 1.0
			"free_refresh": value = 3.0
		if value > best:
			best = value
			selected = index
	if selected < 0: return flow.skip_reward(true)
	var upgrades = flow.crafting.upgrade_candidates(flow.run.build, int(flow.run.act))
	var options = {"recipe_id": upgrades[0].recipe_id, "item_uid": upgrades[0].source_uid} if not upgrades.is_empty() else {}
	return flow.choose_reward(selected, options)

func _resolve_pending(flow):
	while not flow.run.pending_rewards.is_empty():
		if flow.handle_pending(0, "place").ok: continue
		if flow.handle_pending(0, "storage").ok: continue
		if not flow.handle_pending(0, "sell").ok: break

func _event(flow) -> Dictionary:
	if flow.screen_state == "REST": return flow.event_choice("rest_recover")
	var options: Array = []
	for row in db.rows("event_choices"):
		if row.event_id != flow.run.current_node.event_id or not flow.effects.requirements(flow.run, str(row.requirements)).ok: continue
		var effects: Array = []
		for effect in db.rows("event_choice_effects"):
			if effect.choice_id == row.id: effects.append(effect)
		var score = 0.0
		for effect in effects:
			var params = db.parse_params(effect.params)
			match str(effect.effect_type):
				"gold": score += float(params.get("amount", 0)) * 2.0
				"heal_pct": score += minf(float(flow.run.max_health) - float(flow.run.health), float(flow.run.max_health) * float(params.get("amount", 0)))
				"damage_pct": score -= float(flow.run.max_health) * float(params.get("amount", 0))
				"item_pool", "specific_item": score += 12.0
				"bag_pool": score += 8.0
				"upgrade_item": score += 10.0
				"remove_item": score -= 15.0
				"storage_slot": score += 5.0
		options.append({"id": row.id, "score": score})
	options.sort_custom(func(a, b): return a.score > b.score)
	var upgrades = flow.crafting.upgrade_candidates(flow.run.build, int(flow.run.act))
	var selection = {"recipe_id": upgrades[0].recipe_id, "item_uid": upgrades[0].source_uid} if not upgrades.is_empty() else {}
	for option in options:
		var result = flow.event_choice(str(option.id), selection)
		if result.ok: return result
	return {"ok": false, "error": "no_legal_event_choice"}
