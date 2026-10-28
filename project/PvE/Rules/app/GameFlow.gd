class_name GameFlow
extends RefCounted

signal changed
signal notification(key: String)
signal tutorial_changed

const STATES = ["MAIN_MENU", "RUN_SETUP", "ROUTE_SELECT", "SHOP_PREPARE", "COMBAT_PREPARE", "COMBAT_RUNNING", "COMBAT_RESULT", "REWARD_SELECT", "EVENT", "REST", "ACT_RESULT", "RUN_RESULT"]
var db
var saves
var profile_service
var placement
var spatial
var economy
var shop_generator
var crafting
var encounters
var rewards
var effects
var snapshots
var combat
var edit_history
var telemetry
var tutorial
var current_run: RunState
var screen_state: String = "MAIN_MENU"
var last_error: String = ""
var combat_result: Dictionary = {}
var playback_time: float = 0.0
var combat_paused: bool = false
var combat_speed: float = 1.0

var run: Dictionary:
	get: return current_run.data if current_run != null else {}
	set(value): current_run = RunState.new(value)

func _init(content = null, persistence = null):
	db = content
	saves = persistence if persistence != null else SaveService.new()
	var loaded = saves.load_save("profile")
	profile_service = ProfileService.new(db, loaded.data if loaded.ok else {})
	placement = PlacementService.new(db)
	spatial = SpatialQueryService.new(db)
	economy = EconomyService.new(db)
	shop_generator = ShopGenerator.new(db)
	crafting = CraftingService.new(db)
	encounters = EncounterDirector.new(db)
	rewards = RewardService.new(db)
	effects = RunEffectService.new(db)
	snapshots = SnapshotBuilder.new(db)
	combat = CombatEngine.new(db)
	edit_history = BuildState.new(db)
	telemetry = TelemetryService.new(db, saves.base_path)
	tutorial = TutorialService.new(db)

func view_model() -> Dictionary:
	return {"state": screen_state, "run": run.duplicate(true), "profile": profile_service.profile.duplicate(true), "combat": combat_result.duplicate(true), "playback_time": playback_time}

func _fail(key: String) -> Dictionary:
	last_error = key
	notification.emit(key)
	return {"ok": false, "error": key}

func _save() -> bool:
	var success = true
	var failure = ""
	if not run.is_empty():
		run["last_safe_state"] = run.state
		success = saves.save("run", run)
		if not success: failure = saves.last_error
	if not saves.save("profile", profile_service.profile):
		success = false
		failure = saves.last_error
	if not success:
		last_error = failure
		notification.emit("save_write_failed")
	return success

func _update() -> Dictionary:
	if not run.is_empty() and screen_state == "SHOP_PREPARE":
		for slot in run.shop.get("slots", []): profile_service.discover(slot.definition_id)
		for candidate in crafting.candidates(run.build, int(run.act)):
			if candidate.recipe_id not in profile_service.profile.recipes:
				profile_service.recipe(candidate.recipe_id)
				telemetry.record("recipe_discovered", {"recipe_id": candidate.recipe_id, "act": int(run.act)})
	var saved = _save()
	changed.emit()
	return {"ok": saved, "error": "" if saved else "save_write_failed", "committed_in_memory": true}

func _transition(state: String):
	assert(state in STATES)
	screen_state = state
	if not run.is_empty(): run.state = state

func new_run(character_id: String, loadout_id: String, difficulty_id: String, seed_value: int, confirm_overwrite: bool = false) -> Dictionary:
	var previous = saves.load_save("run") if saves.exists("run") else {"ok": false}
	if previous.ok and previous.data.get("state", "") != "RUN_RESULT" and not confirm_overwrite:
		return _fail("confirm_overwrite_run")
	var character = db.get_row("characters", character_id)
	var loadout = db.get_row("character_loadouts", loadout_id)
	var difficulty = db.get_row("difficulty_levels", difficulty_id)
	if character.is_empty() or loadout.is_empty() or loadout.get("character_id", "") != character_id or difficulty.is_empty(): return _fail("invalid_run_setup")
	if difficulty_id not in profile_service.profile.unlocks: return _fail("difficulty_locked")
	if previous.ok and not saves.archive_current_run(): return _fail("save_write_failed")
	seed_value = seed_value & 0xffffffff
	if seed_value == 0: seed_value = 1
	var seeder = DeterministicRNG.new(seed_value)
	run = {"schema_version": 2, "game_version": "0.2.0", "content_version": str(db.value("content_version", "0.1.1")), "run_id": str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(seed_value), "run_seed": seed_value, "rng": {"route": seeder.next_int(), "shop": seeder.next_int(), "reward": seeder.next_int(), "combat": seeder.next_int()}, "character_id": character_id, "loadout_id": loadout_id, "difficulty_id": difficulty_id, "act": 1, "step": 1, "health": float(character.starting_health), "max_health": float(character.max_health), "gold": int(loadout.starting_gold), "build": {"width": int(db.value("grid_width", 9)), "height": int(db.value("grid_height", 7)), "bags": [], "items": [], "storage": [], "storage_capacity": int(db.value("storage_start", 2))}, "shop": {}, "visit": 0, "next_uid": 10, "state": "RUN_SETUP", "route_candidates": [], "current_node": {}, "completed_nodes": [], "pending_rewards": [], "combat_checkpoint": {}, "logs": [], "run_effects": [], "events_seen": [], "recipes_discovered": [], "refreshes_total": 0, "interest_total": 0, "free_refreshes": 0, "started_at": Time.get_unix_time_from_system()}
	run.build.bags.append(_entry(loadout.starting_bag_id, "starting_bag", 0, 0, 0))
	run["content_sha256"] = db.content_sha256
	for row in db.rows("starting_build_items"):
		if row.loadout_id == loadout_id: run.build.items.append(_entry(row.item_id, row.instance_id, int(row.origin_x), int(row.origin_y), int(row.rotation)))
	# A new run begins at the center of the fixed 9x7 editing canvas. Saved
	# layouts are never reflowed: continue_run retains their exact coordinates.
	var starter_max = Vector2i.ZERO
	for bag in run.build.bags:
		for cell in placement.cells(bag):
			starter_max.x = maxi(starter_max.x, cell.x + 1)
			starter_max.y = maxi(starter_max.y, cell.y + 1)
	var starter_offset = Vector2i((9 - starter_max.x) / 2, (7 - starter_max.y) / 2)
	for layer in ["bags", "items"]:
		for entry in run.build[layer]:
			entry.x += starter_offset.x
			entry.y += starter_offset.y
	var valid = placement.validate(run.build)
	if not valid.ok:
		current_run = null
		return _fail(str(valid.error))
	var generated = encounters.generate_act(run)
	if not generated.ok: return _fail(str(generated.error))
	run.route_candidates = encounters.candidates(run)
	profile_service.profile.runs_started = int(profile_service.profile.runs_started) + 1
	for entry in run.build.items + run.build.bags: profile_service.discover(entry.definition_id)
	_transition("ROUTE_SELECT")
	telemetry.record("run_started", {"character_id": character_id, "difficulty_id": difficulty_id, "loadout_id": loadout_id, "seed": seed_value})
	return _update()

func _entry(id: String, uid: String, x: int = 0, y: int = 0, rotation: int = 0) -> Dictionary:
	return {"uid": uid, "definition_id": id, "x": x, "y": y, "rotation": rotation, "used": false, "purchased_visit": -1, "purchase_price": 0}

func continue_run() -> Dictionary:
	var loaded = saves.load_save("run")
	if not loaded.ok: return _fail("save_not_available")
	var valid = saves.validate_run(loaded.data, db)
	if not valid.ok: return _fail(str(valid.error))
	# Validate the complete restore before replacing any live state.
	var draft: Dictionary = loaded.data.duplicate(true)
	if draft.state not in STATES: return _fail("save_invalid_state")
	if not placement.validate(draft.build).ok: return _fail("save_invalid_layout")
	var restored_state = str(draft.state)
	var content_changed = false
	if draft.content_version != str(db.value("content_version", "0.1.1")) or draft.get("content_sha256", "") != db.content_sha256:
		content_changed = true
		draft.content_version = str(db.value("content_version", "0.1.1"))
		draft["content_sha256"] = db.content_sha256
		if restored_state in ["COMBAT_PREPARE", "COMBAT_RUNNING"]:
			draft.combat_checkpoint = {}
			restored_state = "SHOP_PREPARE"
		elif restored_state == "ROUTE_SELECT":
			draft.route_candidates = encounters.candidates(draft)
	var restored_result: Dictionary = {}
	if restored_state in ["COMBAT_PREPARE", "COMBAT_RUNNING"]:
		var checkpoint = draft.combat_checkpoint
		if not checkpoint.has("player") or not checkpoint.has("enemy") or not checkpoint.has("seed"): return _fail("save_invalid_combat")
		restored_result = combat.simulate(checkpoint.player, checkpoint.enemy, int(checkpoint.seed))
		if not bool(restored_result.get("ok", false)): return _fail("save_invalid_combat")
		restored_state = "COMBAT_RUNNING"
	elif restored_state == "COMBAT_RESULT":
		restored_result = draft.get("last_combat_result", {})
		if not bool(restored_result.get("ok", false)) or not restored_result.has("winner_side") or not restored_result.has("elapsed_time") or not restored_result.has("player_remaining_health"): return _fail("save_invalid_combat")
	run = draft
	combat_result = restored_result
	_transition(restored_state)
	if restored_state == "COMBAT_RUNNING":
		playback_time = 0.0
		combat_paused = false
	if screen_state == "SHOP_PREPARE": edit_history.begin_phase(run)
	if content_changed: notification.emit("content_changed_return_to_shop" if restored_state == "SHOP_PREPARE" else "content_changed")
	if bool(loaded.get("recovered", false)): notification.emit("save_backup_recovered")
	return _update()

func go_main_menu() -> Dictionary:
	var saved = _save()
	screen_state = "MAIN_MENU"
	changed.emit()
	return {"ok": saved, "error": "" if saved else "save_write_failed"}

func choose_route(index: int) -> Dictionary:
	if screen_state != "ROUTE_SELECT": return _fail("wrong_state")
	if index < 0 or index >= run.route_candidates.size(): return _fail("invalid_route")
	if not encounters.is_card_allowed(run, run.route_candidates[index]):
		run.route_candidates = encounters.candidates(run)
		_update()
		return _fail("route_no_longer_available")
	var draft = run.duplicate(true)
	draft.current_node = encounters.finalize_card(draft, draft.route_candidates[index])
	var type = str(draft.current_node.type)
	if type.ends_with("combat") or type in ["boss", "merchant"]:
		draft.visit = int(draft.visit) + 1
		var generated = shop_generator.generate(draft, false)
		if not generated.ok: return _fail(str(generated.error))
		if type == "merchant":
			draft.free_refreshes = int(draft.get("free_refreshes", 0)) + 1
			draft.erase("free_refresh_expiry")
		if int(draft.get("shop_discount_remaining", 0)) > 0:
			draft.shop_discount_remaining = int(draft.shop_discount_remaining) - 1
			if int(draft.shop_discount_remaining) == 0: draft.shop_discount = 0.0
		run.clear()
		run.merge(draft, true)
		edit_history.begin_phase(run)
		_transition("SHOP_PREPARE")
	elif type == "event":
		run.current_node = draft.current_node
		_transition("EVENT")
	elif type == "rest":
		run.current_node = draft.current_node
		_transition("REST")
	else: return _fail("unknown_route_type")
	mark_tutorial("select_route")
	telemetry.record("route_choice", {"act": run.act, "step": run.step, "type": type, "enemy_id": run.current_node.get("enemy_id", "")})
	return _update()

func buy(index: int) -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	var before = run.duplicate(true)
	var result = economy.buy(run, index)
	if not result.ok: return _fail(str(result.error))
	if index >= 0 and index < run.shop.slots.size(): profile_service.discover(run.shop.slots[index].definition_id)
	edit_history.record(before, run)
	mark_tutorial("buy_item")
	mark_tutorial("pick_up_item")
	mark_tutorial("place_item_valid")
	telemetry.record("item_purchased", {"item_id": result.entry.definition_id, "price": result.price, "act": run.act, "slot": index})
	return _update()

func buy_at(index: int, x: int, y: int, rotation: int) -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	var before = run.duplicate(true)
	var draft = run.duplicate(true)
	var purchased = economy.buy(draft, index)
	if not purchased.ok: return _fail(str(purchased.error))
	var placed = placement.move(draft.build, purchased.entry.uid, x, y, rotation)
	if not placed.ok: return _fail(str(placed.error))
	run.clear()
	run.merge(draft, true)
	profile_service.discover(purchased.entry.definition_id)
	edit_history.record(before, run)
	mark_tutorial("buy_item")
	mark_tutorial("pick_up_item")
	mark_tutorial("place_item_valid")
	telemetry.record("item_purchased", {"item_id": purchased.entry.definition_id, "price": purchased.price, "act": run.act, "slot": index})
	return _update()

func sell(uid: String, confirmed: bool = false) -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	var before = run.duplicate(true)
	if not confirmed:
		for candidate in crafting.candidates(run.build, int(run.act)):
			if uid in candidate.get("material_uids", candidate.get("materials", [])): return _fail("confirm_sell_recipe_material")
	var result = economy.sell(run, uid)
	if not result.ok: return _fail(str(result.error))
	edit_history.record(before, run)
	telemetry.record("item_sold", {"item_id": result.entry.definition_id, "price": result.price, "used": result.entry.get("used", false)})
	return _update()

func refresh_shop() -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	var before = run.duplicate(true)
	var result = economy.refresh(run)
	if not result.ok: return _fail(str(result.error))
	run.refreshes_total = int(run.get("refreshes_total", 0)) + 1
	profile_service.profile.stats.shop_refreshes = int(profile_service.profile.stats.shop_refreshes) + 1
	mark_tutorial("refresh_shop")
	telemetry.record("shop_refreshed", {"value": 1, "cost": result.cost, "act": run.act})
	edit_history.record(before, run)
	return _update()

func toggle_lock(index: int) -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	var before = run.duplicate(true)
	var result = economy.toggle_lock(run, index)
	if not result.ok: return _fail(str(result.error))
	mark_tutorial("lock_item")
	telemetry.record("shop_locked", {"value": 1 if result.locked else -1, "slot": index})
	edit_history.record(before, run)
	return _update()

func edit(command: String, uid: String = "", options: Dictionary = {}) -> Dictionary:
	if screen_state not in ["SHOP_PREPARE", "REWARD_SELECT"]: return _fail("wrong_state")
	var before = run.duplicate(true)
	var result: Dictionary
	match command:
		"move": result = placement.move(run.build, uid, int(options.get("x", 0)), int(options.get("y", 0)), int(options.get("rotation", 0)))
		"store": result = placement.remove(run.build, uid, true)
		"restore": result = placement.restore(run.build, uid)
		"swap": result = placement.swap(run.build, uid, str(options.get("other_uid", "")))
		"undo": result = edit_history.undo(run)
		"redo": result = edit_history.redo(run)
		_: return _fail("unknown_edit_command")
	if not result.ok: return _fail(str(result.error))
	if command not in ["undo", "redo"]: edit_history.record(before, run)
	if command == "move":
		mark_tutorial("place_item")
		if int(options.get("rotation", 0)) != 0: mark_tutorial("rotate_item")
	if command in ["store", "restore"]: mark_tutorial(command + "_item")
	return _update()

func craft(recipe_id: String, options: Dictionary = {}) -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	var before = run.duplicate(true)
	var result = crafting.execute(run, recipe_id, options)
	if not result.ok: return _fail(str(result.error))
	profile_service.recipe(recipe_id, true)
	profile_service.discover(db.get_row("recipes", recipe_id).result_item_id)
	edit_history.record(before, run)
	mark_tutorial("craft_recipe")
	telemetry.record("recipe_crafted", {"recipe_id": recipe_id, "tier": db.get_row("recipes", recipe_id).tier, "act": run.act})
	return _update()

func handle_pending(index: int, action: String) -> Dictionary:
	if screen_state not in ["SHOP_PREPARE", "REWARD_SELECT"] or index < 0 or index >= run.pending_rewards.size(): return _fail("wrong_state")
	var before = run.duplicate(true)
	var pending: Dictionary = run.pending_rewards[index]
	var kind = str(pending.get("kind", "item"))
	var id = str(pending.get("definition_id", pending.get("result_item_id", "")))
	var row = db.get_row("bags" if kind == "bag" else "items", id)
	if row.is_empty(): return _fail("reward_unknown_definition")
	var allocated = pending.has("entry")
	var entry = pending.entry.duplicate(true) if allocated else _entry(id, "instance_" + str(int(run.next_uid)))
	match action:
		"place":
			var result = placement.auto_place(run.build, entry)
			if not result.ok: return _fail(str(result.error))
		"storage":
			if run.build.storage.size() >= int(run.build.storage_capacity): return _fail("storage_full")
			var result = placement.store(run.build, entry)
			if not result.ok: return _fail(str(result.error))
		"sell": run.gold = int(run.gold) + maxi(1, int(floor(float(row.base_price) * float(db.value("used_sell_ratio", 0.5)))))
		"discard": pass
		_: return _fail("unknown_reward_action")
	if not allocated: run.next_uid = int(run.next_uid) + 1
	run.pending_rewards.remove_at(index)
	profile_service.discover(id)
	edit_history.record(before, run)
	return _update()

func start_combat() -> Dictionary:
	if screen_state != "SHOP_PREPARE": return _fail("wrong_state")
	if not run.pending_rewards.is_empty(): return _fail("unhandled_rewards")
	var valid = placement.validate(run.build)
	if not valid.ok: return _fail(str(valid.error))
	if run.build.items.is_empty(): return _fail("build_has_no_items")
	if run.current_node.type == "merchant": return complete_node()
	var tutorial_gate = tutorial.can_start(profile_service.profile, run, not crafting.candidates(run.build, int(run.act)).is_empty())
	if not tutorial_gate.ok: return _fail(tutorial_gate.error)
	var before = run.duplicate(true)
	_transition("COMBAT_PREPARE")
	var player = snapshots.player(run)
	var enemy = snapshot_enemy(run.current_node)
	if not bool(player.get("ok", false)) or not bool(enemy.get("ok", false)):
		_transition("SHOP_PREPARE")
		return _fail("invalid_combat_snapshot")
	var rng = DeterministicRNG.new(int(run.rng.combat))
	var seed_value = rng.next_int()
	var simulated: Dictionary = combat.simulate(player, enemy, seed_value)
	if not bool(simulated.get("ok", false)):
		run.clear()
		run.merge(before, true)
		screen_state = "SHOP_PREPARE"
		return _fail("invalid_combat_snapshot")
	run.rng.combat = rng.state
	run.combat_checkpoint = {"player": player, "enemy": enemy, "seed": seed_value, "content_version": run.content_version}
	_transition("COMBAT_RUNNING")
	if not _save():
		run.clear()
		run.merge(before, true)
		screen_state = "SHOP_PREPARE"
		return _fail("save_write_failed")
	edit_history.begin_phase(run)
	combat_result = simulated
	telemetry.record("used_cell_count", {"value": placement.validate(run.build).get("item_occupancy", {}).size()})
	playback_time = 0.0
	combat_paused = false
	combat_speed = 1.0
	changed.emit()
	return {"ok": true, "error": ""}

func snapshot_enemy(node: Dictionary) -> Dictionary:
	if not str(node.get("boss_id", "")).is_empty(): return snapshots.boss(node.boss_id, run.difficulty_id)
	return snapshots.enemy(str(node.get("enemy_id", "")), run.difficulty_id, node.get("affix_ids", node.get("affix_id", "")))

func item_preview(uid: String) -> Dictionary:
	if run.is_empty(): return {}
	var player = snapshots.player(run)
	if not bool(player.get("ok", false)): return {}
	var enemy = {} if run.current_node.get("type", "") == "merchant" else snapshot_enemy(run.current_node)
	var preview = CombatEngine.new(db).preview(player, enemy)
	if not bool(preview.get("ok", false)): return {}
	return preview.items.get(uid, {}).duplicate(true)

func advance_combat(seconds: float):
	if screen_state != "COMBAT_RUNNING" or combat_paused: return
	playback_time += maxf(0.0, seconds) * combat_speed
	if playback_time >= float(combat_result.get("elapsed_time", 0)):
		var deltas: Dictionary = combat_result.get("run_deltas", {})
		run.gold = int(run.gold) + int(deltas.get("gold", 0))
		run["free_refreshes"] = int(run.get("free_refreshes", 0)) + int(deltas.get("free_refresh", 0))
		if int(deltas.get("free_refresh", 0)) > 0: run.erase("free_refresh_expiry")
		run.max_health = float(run.max_health) + float(deltas.get("max_health", 0))
		run.health = maxf(0.0, float(combat_result.get("player_remaining_health", 0)))
		run["last_combat_result"] = combat_result.duplicate(true)
		economy.mark_used(run.build)
		profile_service.on_combat(run, combat_result)
		telemetry.record("combat_result", {"enemy_id": run.current_node.get("enemy_id", run.current_node.get("boss_id", "")), "result": "win" if int(combat_result.winner_side) == 0 else "loss", "duration_seconds": combat_result.elapsed_time, "remaining_health": run.health, "replay_digest": combat_result.replay_digest})
		profile_service.profile.stats.max_used_cells = maxi(int(profile_service.profile.stats.max_used_cells), placement.validate(run.build).get("item_occupancy", {}).size())
		run.logs.append({"node": run.current_node.duplicate(true), "digest": combat_result.get("replay_digest", ""), "time": combat_result.elapsed_time, "winner": combat_result.winner_side, "health": run.health, "item_stats_by_instance_id": combat_result.get("item_stats_by_instance_id", {}).duplicate(true), "key_events": combat_result.get("key_events", []).duplicate(true)})
		if run.logs.size() > 18: run.logs.pop_front()
		_transition("COMBAT_RESULT")
		mark_tutorial("view_combat_result")
		mark_tutorial("wait_for_first_activation")
		_update()

func confirm_combat() -> Dictionary:
	if screen_state != "COMBAT_RESULT": return _fail("wrong_state")
	if int(combat_result.winner_side) != 0:
		_transition("RUN_RESULT")
		profile_service.on_run_ended(run, false)
		telemetry.record("run_ended", {"result": "defeat", "act": run.act, "nodes": run.completed_nodes.size(), "duration": run.get("play_seconds", 0)})
		return _update()
	var income = economy.battle_income(run, run.current_node.type == "elite_combat", run.current_node.type == "boss")
	run.interest_total = int(run.get("interest_total", 0)) + int(income.get("interest", 0))
	telemetry.record("interest_awarded", {"value": int(income.get("interest", 0))})
	var curve = db.get_row("economy_curve", "act_" + str(int(run.act)))
	var difficulty = db.get_row("difficulty_levels", run.difficulty_id)
	run.health = minf(float(run.max_health), float(run.health) + float(run.max_health) * float(curve.get("post_battle_heal_pct", 0)) * float(difficulty.get("post_battle_heal_scalar", 1)))
	if int(run.get("interest_bonus_remaining", 0)) > 0:
		run.interest_bonus_remaining = int(run.interest_bonus_remaining) - 1
		if int(run.interest_bonus_remaining) == 0: run.interest_cap_delta = 0
	run["reward_choices"] = rewards.generate(run, run.current_node.reward_table_id)
	run["reward_selected"] = false
	_transition("REWARD_SELECT")
	return _update()

func choose_reward(index: int, options: Dictionary = {}) -> Dictionary:
	if screen_state != "REWARD_SELECT" or bool(run.get("reward_selected", false)): return _fail("wrong_state")
	if index < 0 or index >= run.reward_choices.size(): return _fail("invalid_reward")
	var reward: Dictionary = run.reward_choices[index]
	var type = str(reward.type)
	if type in ["item_pool", "bag_pool"]:
		run.pending_rewards.append({"kind": reward.get("kind", "item"), "definition_id": reward.definition_id, "source": "reward", "type": "pending_item"})
	else:
		var result = effects.apply(run, [{"effect_type": type, "params": reward.params}], options)
		if not result.ok: return _fail(str(result.error))
	run.reward_selected = true
	_sync_discoveries()
	mark_tutorial("select_reward")
	telemetry.record("reward_selected", {"reward_table": reward.table_id, "reward_id": reward.id, "item_id": reward.get("definition_id", "")})
	return _update()

func skip_reward(confirmed: bool = false) -> Dictionary:
	if screen_state != "REWARD_SELECT" or bool(run.get("reward_selected", false)): return _fail("wrong_state")
	if not confirmed:
		for reward in run.reward_choices:
			var row = db.get_row("items", str(reward.get("definition_id", "")))
			if row.get("rarity", "") in ["rare", "legendary"]: return _fail("confirm_skip_rare_reward")
	var table = db.get_row("reward_tables", run.current_node.reward_table_id)
	if not bool(table.get("allow_skip", true)): return _fail("reward_skip_not_allowed")
	run.gold = int(run.gold) + int(table.get("skip_gold", 1))
	run.reward_selected = true
	telemetry.record("reward_skipped", {"value": 1, "gold": int(table.get("skip_gold", 1))})
	mark_tutorial("select_reward")
	return _update()

func event_choice(id: String, options: Dictionary = {}) -> Dictionary:
	if screen_state not in ["EVENT", "REST"]: return _fail("wrong_state")
	var is_rest = screen_state == "REST"
	var row = db.get_row("rest_actions" if is_rest else "event_choices", id)
	if row.is_empty() or (not is_rest and row.event_id != run.current_node.event_id): return _fail("invalid_event_choice")
	var valid = effects.requirements(run, str(row.requirements))
	if not valid.ok: return _fail(str(valid.error))
	var choices: Array = []
	for effect in db.rows("rest_action_effects" if is_rest else "event_choice_effects"):
		if effect.get("rest_action_id" if is_rest else "choice_id", "") == id: choices.append(effect)
	choices.sort_custom(func(a, b): return int(a.sequence) < int(b.sequence))
	var result = effects.apply(run, choices, options)
	if not result.ok: return _fail(str(result.error))
	if not is_rest:
		if run.current_node.event_id not in run.events_seen: run.events_seen.append(run.current_node.event_id)
		if run.current_node.event_id not in profile_service.profile.seen_events: profile_service.profile.seen_events.append(run.current_node.event_id)
		profile_service.profile.stats.events_seen = profile_service.profile.seen_events.size()
		telemetry.record("event_choice", {"event_id": run.current_node.event_id, "choice_id": id, "gold": run.gold, "health": run.health})
	run.reward_selected = true
	run.reward_choices = []
	_sync_discoveries()
	if not run.pending_rewards.is_empty(): _transition("REWARD_SELECT")
	else: return complete_node()
	return _update()

func _sync_discoveries():
	for id in run.get("recipes_discovered", []): profile_service.recipe(id)
	profile_service.check_achievements(run)

func complete_node() -> Dictionary:
	if screen_state == "REWARD_SELECT":
		if not bool(run.get("reward_selected", false)) or not run.pending_rewards.is_empty(): return _fail("unhandled_rewards")
	elif screen_state == "SHOP_PREPARE":
		if run.current_node.type != "merchant" or not run.pending_rewards.is_empty(): return _fail("wrong_state")
	elif screen_state not in ["EVENT", "REST"]: return _fail("wrong_state")
	run.completed_nodes.append(run.current_node.duplicate(true))
	telemetry.record("storage_usage", {"value": run.build.storage.size(), "capacity": int(run.build.storage_capacity)})
	effects.expire_node(run)
	run.combat_checkpoint = {}
	if run.current_node.type == "boss":
		if int(run.act) == 3:
			_transition("RUN_RESULT")
			profile_service.on_run_ended(run, true)
			telemetry.record("run_ended", {"result": "clear", "act": run.act, "nodes": run.completed_nodes.size(), "duration": run.get("play_seconds", 0)})
			telemetry.record("difficulty_clear", {"character_id": run.character_id, "difficulty_id": run.difficulty_id})
		else:
			var act = db.get_row("acts", "act_" + str(int(run.act) + 1))
			var old_capacity = int(run.build.storage_capacity)
			var target_capacity = mini(int(db.value("storage_cap", 4)), int(run.act) + 2)
			run.build.storage_capacity = maxi(old_capacity, target_capacity)
			if int(run.build.storage_capacity) == old_capacity: run.gold = int(run.gold) + 5
			_transition("ACT_RESULT")
	else:
		run.step = int(run.step) + 1
		run.route_candidates = encounters.candidates(run)
		_transition("ROUTE_SELECT")
	return _update()

func next_act() -> Dictionary:
	if screen_state != "ACT_RESULT": return _fail("wrong_state")
	var draft = run.duplicate(true)
	draft.act = int(draft.act) + 1
	draft.step = 1
	var result = encounters.generate_act(draft)
	if not result.ok: return _fail(str(result.error))
	run.clear()
	run.merge(draft, true)
	run.route_candidates = encounters.candidates(run)
	_transition("ROUTE_SELECT")
	return _update()

func mark_tutorial(action: String):
	if run.is_empty(): return
	var aliases = {"buy_item": "confirm_purchase", "place_item": "place_item_valid", "view_enemy": "open_enemy_preview", "view_combat_result": "open_combat_stats", "lock_item": "lock_shop_item", "store_item": "move_item_to_storage", "craft_recipe": "confirm_recipe", "select_route": "select_route_node"}
	action = str(aliases.get(action, action))
	var updated = false
	for step in db.rows("tutorial_steps"):
		if str(step.required_action) == action and step.id not in profile_service.profile.tutorial_completed:
			profile_service.profile.tutorial_completed.append(step.id)
			telemetry.record("tutorial_step", {"step_id": step.id})
			updated = true
	if updated: tutorial_changed.emit()

func skip_tutorial():
	for step in db.rows("tutorial_steps"):
		if step.id not in profile_service.profile.tutorial_completed: profile_service.profile.tutorial_completed.append(step.id)
	_update()

# Native bags carry their contained items. Validate the entire transformed build
# before committing; rejected drops preserve gold, RNG, history and every UID.
func move_bag_with_contents(uid: String, options: Dictionary = {}) -> Dictionary:
	if screen_state != "SHOP_PREPARE": return {"ok": false, "error": "wrong_state"}
	var before = run.duplicate(true)
	var draft = before.duplicate(true)
	var found = placement.find(draft.build, uid)
	if found.is_empty() or found.layer != "bags": return {"ok": false, "error": "missing_item"}
	var original: Dictionary = found.entry
	var target_rotation = int(options.get("rotation", original.rotation))
	if target_rotation not in placement.rotations(original): return {"ok": false, "error": "rotation"}
	var turns = posmod(target_rotation - int(original.rotation), 360) / 90
	var minimum = Vector2i(2147483647, 2147483647)
	for cell in placement.local_cells(original):
		var transformed = Vector2i(cell)
		for turn in range(turns): transformed = Vector2i(-transformed.y, transformed.x)
		minimum.x = mini(minimum.x, transformed.x)
		minimum.y = mini(minimum.y, transformed.y)
	var old_cells = placement.cells(original)
	var x = int(options.get("x", original.x))
	var y = int(options.get("y", original.y))
	var moved = []
	for item in draft.build.items:
		var contained = true
		for cell in placement.cells(item):
			if cell not in old_cells: contained = false; break
		if not contained: continue
		var item_rotation = posmod(int(item.rotation) + turns * 90, 360)
		if item_rotation not in placement.rotations(item): return {"ok": false, "error": "rotation"}
		var new_minimum = Vector2i(2147483647, 2147483647)
		for cell in placement.cells(item):
			var transformed = Vector2i(cell) - Vector2i(int(original.x), int(original.y))
			for turn in range(turns): transformed = Vector2i(-transformed.y, transformed.x)
			new_minimum.x = mini(new_minimum.x, transformed.x)
			new_minimum.y = mini(new_minimum.y, transformed.y)
		item.x = x + new_minimum.x - minimum.x
		item.y = y + new_minimum.y - minimum.y
		item.rotation = item_rotation
		moved.append(str(item.uid))
	draft.build.bags[found.index].x = x
	draft.build.bags[found.index].y = y
	draft.build.bags[found.index].rotation = target_rotation
	var result = placement.validate(draft.build)
	if not result.ok: return result
	if bool(options.get("preview", false)): return {"ok": true, "error": "", "build": draft.build, "moved_uids": moved}
	run.clear(); run.merge(draft, true)
	edit_history.record(before, run)
	mark_tutorial("place_item")
	if turns != 0: mark_tutorial("rotate_item")
	return _update()
