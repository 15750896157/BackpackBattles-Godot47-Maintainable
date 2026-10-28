extends SceneTree

# Scene-free integration tests. Boss transition fixtures test state/economy rules;
# they are separate from the production CombatEngine's combat correctness suite.
var db
var checks = 0
var failures: Array = []
var base = "user://qa_flow_contract/"
var phase = "contracts"

class MemorySaves:
	extends RefCounted
	var data: Dictionary = {}
	var last_error = ""
	var fail_write = false
	var base_path = "user://qa_flow_contract_memory/"
	func load_save(kind: String) -> Dictionary:
		return {"ok": data.has(kind), "error": "" if data.has(kind) else "missing", "data": data.get(kind, {}).duplicate(true), "recovered": false}
	func exists(kind: String) -> bool:
		return data.has(kind)
	func save(kind: String, value: Dictionary) -> bool:
		if fail_write:
			last_error = "save_write_failed"
			return false
		data[kind] = value.duplicate(true)
		return true
	func validate_run(_value: Dictionary, _content) -> Dictionary:
		return {"ok": true, "error": ""}

class FailedShop:
	extends RefCounted
	func generate(_run: Dictionary, _refresh: bool = false) -> Dictionary:
		return {"ok": false, "error": "fixture_shop_failure"}

class FailedEncounter:
	extends RefCounted
	func generate_act(_run: Dictionary) -> Dictionary:
		return {"ok": false, "error": "fixture_route_failure"}

class FailedCombat:
	extends RefCounted
	func simulate(_player: Dictionary, _enemy: Dictionary, _seed: int) -> Dictionary:
		return {"ok": false, "error": "fixture_simulation_failure", "winner_side": 1, "elapsed_time": 0.0}

func _init():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--base="): base = argument.trim_prefix("--base=")
	base = base.replace("\\", "/").trim_suffix("/") + "/"
	call_deferred("_run")

func _run():
	db = ContentDB.new()
	if not db.errors.is_empty():
		failures.append("content unavailable: " + str(db.errors))
		_finish()
		return
	match phase:
		"write": _write_cross_process_fixture()
		"read": _read_cross_process_fixture()
		"invalid_checkpoint": _test_invalid_checkpoint()
		"simulation_failure": _test_simulation_failure()
		_:
			_test_routes()
			_test_flow_history()
			_test_failure_transactions()
			_test_effects()
			_test_pending()
			_test_chapter_flow()
			_test_saves()
	_finish()

func _check(value: bool, label: String):
	checks += 1
	if not value:
		failures.append(label)
		push_error("CONTRACT FAIL: " + label)

func _entry(id: String, uid: String, x: int = 0, y: int = 0) -> Dictionary:
	return {"uid": uid, "definition_id": id, "x": x, "y": y, "rotation": 0, "used": false, "purchased_visit": -1, "purchase_price": 0}

func _flow(shop: bool = true):
	var memory = MemorySaves.new()
	memory.base_path = base + "memory/"
	var flow = GameFlow.new(db, memory)
	var result = flow.new_run("armorer", "armorer_blades", "standard", 12345, true)
	_check(result.ok, "new actual configured run")
	if shop and result.ok:
		_check(flow.choose_route(0).ok, "first actual route enters shop")
	return flow

func _same(left: Dictionary, right: Dictionary) -> bool:
	return left == right

func _test_routes():
	var director = EncounterDirector.new(db)
	for act in [1, 2, 3]:
		var run = {"act": act, "step": 1, "rng": {"route": 400 + act}, "completed_nodes": [], "events_seen": []}
		_check(director.generate_act(run).ok and run.route_plan.size() == 5, "five steps in act %d" % act)
		for step in [2, 3, 4]:
			run.step = step
			for previous in ["normal_combat", "merchant", "rest", "event"]:
				run.completed_nodes = [{"type": previous}]
				var before = run.duplicate(true)
				var candidates = director.candidates(run)
				_check(candidates.size() >= 2 and candidates.size() <= 3, "filtered route count act%d step%d after %s" % [act, step, previous])
				var types: Array = []
				for card in candidates:
					_check(not types.has(card.type), "route card types unique")
					types.append(card.type)
					if previous in ["merchant", "rest", "event"]:
						_check(card.type not in ["merchant", "rest", "event"], "no consecutive noncombat nodes")
				_check(run == before and candidates == director.candidates(run), "route query pure and stable")
		var card = director.make_card(run, "danger_combat", DeterministicRNG.new(31))
		run.completed_nodes = [{"type": "danger_combat", "enemy_id": card.enemy_id}]
		var selected = director.finalize_card(run, card)
		_check(selected.enemy_id != card.enemy_id, "enemy repeat limit replaces exhausted encounter")
		run.step = 5
		var last = director.candidates(run)
		_check(last.size() == 1 and last[0].type == "boss" and not last[0].boss_id.is_empty(), "last step single defined boss")
	var a = {"act": 2, "step": 1, "rng": {"route": 991, "shop": 117}, "completed_nodes": [], "events_seen": []}
	var b = a.duplicate(true)
	director.generate_act(a)
	director.generate_act(b)
	_check(a == b and a.rng.shop == 117, "route determinism with isolated RNG")

func _test_flow_history():
	var flow = _flow()
	flow.run.shop.slots = [{"definition_id": "utility_knife", "kind": "item", "base_price": 2, "price": 2, "sold": false, "locked": false}]
	var before = flow.run.duplicate(true)
	_check(flow.buy(0).ok, "flow buy")
	var after = flow.run.duplicate(true)
	_check(flow.edit("undo").ok and _same(flow.run, before), "full run undo purchase gold slot UID inventory")
	_check(flow.edit("redo").ok and _same(flow.run, after), "full run redo exact purchase")
	flow.run.gold = 100
	flow.edit_history.begin_phase(flow.run)
	before = flow.run.duplicate(true)
	_check(flow.refresh_shop().ok, "flow refresh")
	after = flow.run.duplicate(true)
	_check(flow.edit("undo").ok and _same(flow.run, before), "undo refresh restores RNG offers cost and refresh counter")
	_check(flow.edit("redo").ok and _same(flow.run, after), "redo refresh reproduces same offers")
	var bag_origin = Vector2i(int(flow.run.build.bags[0].x), int(flow.run.build.bags[0].y))
	flow.run.build.items = [_entry("utility_knife", "craft_knife", bag_origin.x, bag_origin.y), _entry("sharpening_stone", "craft_stone", bag_origin.x + 1, bag_origin.y)]
	flow.edit_history.begin_phase(flow.run)
	before = flow.run.duplicate(true)
	_check(flow.craft("recipe_iron_sword").ok, "flow manual craft")
	after = flow.run.duplicate(true)
	_check(flow.edit("undo").ok and _same(flow.run, before), "flow craft undo preserves all materials discovery UID")
	_check(flow.edit("redo").ok and _same(flow.run, after), "flow craft redo complete output")
	flow.edit_history.begin_phase(flow.run)
	for i in range(25):
		flow.run.gold = 100
		flow.toggle_lock(0)
	_check(flow.edit_history.undo_stack.size() == 20, "flow history retains last twenty intents")

func _test_failure_transactions():
	var flow = _flow()
	flow.run.shop.slots = [{"definition_id": "utility_knife", "kind": "item", "base_price": 2, "price": 2, "sold": false, "locked": false}]
	var before = flow.run.duplicate(true)
	_check(not flow.buy_at(0, 8, 6, 0).ok and flow.run == before, "invalid drop purchase no partial charge or UID")
	flow.run.gold = 0
	before = flow.run.duplicate(true)
	_check(not flow.buy(0).ok and flow.run == before, "buy failure leaves run unchanged")
	_check(not flow.refresh_shop().ok and flow.run == before, "refresh failure leaves RNG unchanged")
	flow = _flow(false)
	flow.shop_generator = FailedShop.new()
	before = flow.run.duplicate(true)
	_check(not flow.choose_route(0).ok and flow.run == before and flow.screen_state == "ROUTE_SELECT", "failed route shop generation rolls back node visit")
	flow = _flow(false)
	flow._transition("ACT_RESULT")
	flow.encounters = FailedEncounter.new()
	before = flow.run.duplicate(true)
	_check(not flow.next_act().ok and flow.run == before and flow.screen_state == "ACT_RESULT", "failed act generation rolls back chapter progress")
	flow = _flow()
	flow.run.current_node.enemy_id = "fixture_missing_enemy"
	before = flow.run.duplicate(true)
	_check(not flow.start_combat().ok and flow.run == before and flow.screen_state == "SHOP_PREPARE", "invalid snapshot does not start or consume combat RNG")
	flow = _flow()
	flow.saves.fail_write = true
	flow.run.shop.slots = [{"definition_id": "utility_knife", "kind": "item", "base_price": 2, "price": 2, "sold": false, "locked": false}]
	_check(not flow.buy(0).ok and flow.last_error == "save_write_failed", "flow reports autosave failure")

func _test_effects():
	var effects = RunEffectService.new(db)
	var flow = _flow()
	flow.run.gold = 20
	flow.run.act = 2
	flow.run.build.items = [_entry("iron_sword", "upgrade_target", 0, 0)]
	var before = flow.run.duplicate(true)
	var forged = [{"effect_type": "gold", "params": "amount:-4"}, {"effect_type": "upgrade_item", "params": "tier_max:2|selector:player_choice"}]
	_check(not effects.apply(flow.run, forged, {"item_uid": "wrong", "recipe_id": "recipe_chain_blade"}).ok and flow.run == before, "failed selected upgrade rolls back previous gold effect")
	_check(effects.apply(flow.run, forged, {"item_uid": "upgrade_target", "recipe_id": "recipe_chain_blade"}).ok and flow.run.gold == 16, "selected defined upgrade charges exactly once")
	_check(flow.run.build.items[0].definition_id == "chain_blade" and flow.run.build.items[0].craft_tier == 2, "upgrade has defined tier two output")
	var fallback = _flow()
	fallback.run.build.items = [_entry("utility_knife", "not_tier_one")]
	_check(effects.apply(fallback.run, [{"effect_type": "upgrade_item", "params": "fallback_discount:0.20|duration_shops:1"}]).ok and fallback.run.shop_discount == 0.2, "upgrade with no target becomes one shop discount")
	var rewards = RewardService.new(db)
	var a = fallback.run.duplicate(true)
	var b = a.duplicate(true)
	var first = rewards.generate(a, "reward_normal")
	_check(first == rewards.generate(b, "reward_normal") and a.rng.shop == fallback.run.rng.shop, "reward deterministic isolated stream")
	var ids: Array = []
	for reward in first:
		_check(reward.id not in ids, "reward choice IDs unique")
		ids.append(reward.id)
		if reward.type == "item_pool":
			var item = db.get_row("items", str(reward.definition_id))
			_check(not item.is_empty() and int(item.chapter_min) <= int(a.act) and item.owner_pool in ["public", a.character_id], "reward pool chapter and owner filtered")
	flow = _flow()
	flow._transition("EVENT")
	flow.run.current_node = {"type": "event", "event_id": "event_field_smith", "reward_table_id": "reward_none"}
	flow.run.act = 2
	flow.run.gold = 20
	flow.run.build.items = [_entry("iron_sword", "event_upgrade", 0, 0)]
	before = flow.run.duplicate(true)
	_check(not flow.event_choice("event_field_smith_forge", {"item_uid": "wrong", "recipe_id": "recipe_chain_blade"}).ok and flow.run == before, "event transaction no charge for invalid upgrade selection")
	_check(flow.event_choice("event_field_smith_forge", {"item_uid": "event_upgrade", "recipe_id": "recipe_chain_blade"}).ok and flow.run.gold == 16, "event valid choice applies cost and output once")
	_check(not flow.event_choice("event_field_smith_forge").ok, "completed event choice cannot repeat")
	var removal = _flow()
	removal.run.gold = 20
	removal.run.build.items = [_entry("utility_knife", "remove_candidate")]
	before = removal.run.duplicate(true)
	_check(not effects.apply(removal.run, [{"effect_type": "gold", "params": "amount:-3"}, {"effect_type": "remove_item", "params": "selector:player_choice"}], {"item_uid": "missing"}).ok and removal.run == before, "invalid item removal rolls back prior payment")
	_check(not effects.apply(removal.run, [{"effect_type": "remove_item", "params": "selector:player_choice"}, {"effect_type": "gold", "params": "amount:-999"}], {"item_uid": "remove_candidate"}).ok and removal.run == before, "later failed effect restores previously removed material")
	removal._transition("EVENT")
	removal.run.current_node = {"type": "event", "event_id": "event_barter_table", "reward_table_id": "reward_none"}
	before = removal.run.duplicate(true)
	_check(not removal.event_choice("event_barter_table_swap", {"item_uid": "missing"}).ok and removal.run == before, "event remove invalid selection preserves run RNG inventory")
	_check(removal.event_choice("event_barter_table_swap", {"item_uid": "remove_candidate"}).ok and removal.run.build.items.is_empty() and removal.run.pending_rewards.size() == 1, "valid event swaps exactly selected material into pending reward")
	_check(removal.screen_state == "REWARD_SELECT" and removal.run.pending_rewards[0].source == "event", "event pending output uses explicit resolve phase")
	_check(not removal.complete_node().ok and removal.handle_pending(0, "storage").ok and removal.complete_node().ok, "pending event reward blocks route until manually resolved")

func _test_pending():
	var flow = _flow()
	var entry = _entry("iron_sword", "pending_craft_uid")
	entry["crafted"] = true
	entry["craft_tier"] = 1
	entry["used"] = true
	entry["materials"] = [_entry("utility_knife", "material_a"), _entry("sharpening_stone", "material_b")]
	flow.run.pending_rewards = [{"kind": "item", "definition_id": "iron_sword", "source": "craft", "entry": entry.duplicate(true)}]
	var next_uid = int(flow.run.next_uid)
	var before = flow.run.duplicate(true)
	_check(not flow.start_combat().ok and flow.run == before, "unhandled output blocks battle")
	_check(flow.handle_pending(0, "storage").ok, "manual pending storage")
	_check(flow.run.build.storage[0] == entry and int(flow.run.next_uid) == next_uid, "pending complete entry metadata and stable UID retained")
	_check(flow.edit("undo").ok and flow.run == before, "pending resolution undo restores exact pending entry")
	_check(flow.edit("redo").ok and flow.run.build.storage[0] == entry, "pending resolution redo keeps materials and used flag")

func _test_chapter_flow():
	var flow = _flow()
	for act in [1, 2, 3]:
		flow.run.act = act
		flow.run.step = 5
		flow.run.health = 41.0
		flow.run.gold = 13
		flow.run.current_node = {"type": "boss", "boss_id": _boss_id(act), "enemy_id": "", "affix_id": "", "reward_table_id": "reward_boss"}
		flow.combat_result = {"winner_side": 0, "player_remaining_health": 41.0, "elapsed_time": 10.0, "replay_digest": "transition_fixture"}
		flow._transition("COMBAT_RESULT")
		_check(flow.confirm_combat().ok and flow.screen_state == "REWARD_SELECT", "boss result enters reward act%d" % act)
		var expected_health = 41.0 + float(db.get_row("economy_curve", "act_%d" % act).post_battle_heal_pct) * float(flow.run.max_health)
		_check(is_equal_approx(float(flow.run.health), expected_health) and flow.run.gold == 13, "boss preserves sustained health with configured healing no base gold")
		flow.run.reward_choices = [{"id": "fixture_no_gold", "table_id": "reward_boss", "type": "gold", "params": {"amount": 0}, "definition_id": ""}]
		_check(flow.choose_reward(0).ok and flow.complete_node().ok, "boss reward completion act%d" % act)
		if act < 3:
			_check(flow.screen_state == "ACT_RESULT", "act result transition")
			_check(flow.next_act().ok and int(flow.run.act) == act + 1 and flow.run.step == 1, "next chapter progress")
			_check(int(flow.run.build.storage_capacity) == act + 2, "fixed chapter storage grows 3 then4")
			_check(is_equal_approx(float(flow.run.health), expected_health), "next chapter retains life rather than full reset")
		else:
			_check(flow.screen_state == "RUN_RESULT" and bool(flow.run.profile_result_recorded), "final boss clear ends run and profile records")
			var clears = int(flow.profile_service.profile.stats.runs_cleared)
			flow.profile_service.on_run_ended(flow.run, true)
			_check(int(flow.profile_service.profile.stats.runs_cleared) == clears, "run clear profile idempotent")
	var early = _flow()
	early.run.act = 1
	early.run.step = 5
	early.run.gold = 10
	early.run.build.storage_capacity = 3
	early.run.current_node = {"type": "boss", "boss_id": _boss_id(1), "reward_table_id": "reward_boss"}
	early.run.reward_selected = true
	early._transition("REWARD_SELECT")
	_check(early.complete_node().ok and early.run.build.storage_capacity == 3 and early.run.gold == 15, "already granted chapter storage compensated rather than grants next slot early")

func _boss_id(act: int) -> String:
	for row in db.rows("bosses"):
		if row.act_id == "act_%d" % act: return str(row.id)
	return ""

func _test_saves():
	var zero = DeterministicRNG.new(0)
	_check(zero.state == 0 and zero.next_int() == 1013904223, "LCG zero state is restored rather than reseeded")
	var directory = base + "save_contracts/"
	var saves = SaveService.new(directory)
	_check(saves.save("run", {"schema_version": 2, "revision": 1, "rng": {"shop": 4294967295}}), "first atomic save")
	_check(saves.save("run", {"schema_version": 2, "revision": 2, "rng": {"shop": 4294967295}}), "second atomic save replaces primary")
	var backup = saves._read(directory + "run_backup.save")
	_check(backup.ok and int(backup.data.revision) == 1, "backup is previous verified primary")
	var file = FileAccess.open(directory + "run.save", FileAccess.WRITE)
	file.store_string(JSON.stringify({"envelope_version": 1, "payload": "{}", "sha256": "fixture_invalid_checksum"}))
	file.close()
	var recovered = saves.load_save("run")
	_check(recovered.ok and recovered.recovered and int(recovered.data.revision) == 1, "bad primary recovers verified backup")
	_check(saves.save("run", recovered.data), "repair corrupted primary")
	_check(int(saves._read(directory + "run_backup.save").data.revision) == 1, "corrupt primary never overwrites good backup")
	var invalid = saves.load_save("run").data.duplicate(true)
	_check(not saves.validate_run(invalid, db).ok, "structurally missing run rejected")
	var flow = _flow(false)
	var missing = flow.run.duplicate(true)
	missing.erase("content_version")
	_check(not saves.validate_run(missing, db).ok, "missing direct-access content version rejected before continue")
	missing = flow.run.duplicate(true)
	missing.rng.erase("combat")
	_check(not saves.validate_run(missing, db).ok, "missing RNG stream rejected before continue")
	missing = flow.run.duplicate(true)
	missing.rng.shop = 1.5
	_check(not saves.validate_run(missing, db).ok, "fractional RNG stream rejected")
	var old = flow.run.duplicate(true)
	old.schema_version = 1
	old["current_health"] = 37.0
	old.erase("health")
	var legacy_dir = base + "migration/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(legacy_dir))
	file = FileAccess.open(legacy_dir + "run.save", FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var legacy = SaveService.new(legacy_dir)
	var migrated = legacy.load_save("run")
	_check(migrated.ok and migrated.data.schema_version == 2 and migrated.data.health == 37.0 and not migrated.data.has("current_health"), "schema1 current_health migrates to schema2 health")
	_check(FileAccess.file_exists(legacy_dir + "run_before_migration_v1.save"), "pre-migration original retained")
	_check(not saves.save("unapproved_kind", {}), "unknown save kind rejected")

func _write_cross_process_fixture():
	var flow = GameFlow.new(db, SaveService.new(base))
	_check(flow.new_run("armorer", "armorer_blades", "standard", 67731, true).ok, "cross process create")
	_check(flow.choose_route(0).ok, "cross process shop")
	flow.run.health = 63.0
	flow.run.gold = 37
	var entry = _entry("iron_sword", "persisted_pending")
	entry["crafted"] = true
	entry["craft_tier"] = 1
	entry["materials"] = [_entry("utility_knife", "p_a"), _entry("sharpening_stone", "p_b")]
	flow.run.pending_rewards = [{"kind": "item", "definition_id": "iron_sword", "source": "craft", "entry": entry}]
	_check(flow._save(), "cross process save full run")
	var expected = FileAccess.open(base + "expected.json", FileAccess.WRITE)
	expected.store_string(JSON.stringify(flow.run, "", true))
	expected.close()
	var legacy = flow.run.duplicate(true)
	legacy.schema_version = 1
	legacy["current_health"] = legacy.health
	legacy.erase("health")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base + "cross_migration/"))
	var old_file = FileAccess.open(base + "cross_migration/run.save", FileAccess.WRITE)
	old_file.store_string(JSON.stringify(legacy))
	old_file.close()
	_check(FileAccess.file_exists(base + "cross_migration/run.save"), "cross process legacy fixture written")

func _test_invalid_checkpoint():
	var original = _flow(false)
	var data = original.run.duplicate(true)
	data.state = "COMBAT_RUNNING"
	data.combat_checkpoint = {"player": {}, "enemy": {}, "seed": 1}
	var saves = SaveService.new(base + "invalid_checkpoint/")
	_check(saves.save("run", data), "invalid checkpoint fixture has a valid outer save checksum")
	var flow = GameFlow.new(db, saves)
	var result = flow.continue_run()
	_check(not result.ok, "invalid combat snapshot is rejected during continue rather than played")
	_check(flow.screen_state != "COMBAT_RUNNING", "invalid checkpoint cannot enter running playback")

func _test_simulation_failure():
	var flow = _flow()
	flow.combat = FailedCombat.new()
	var before = flow.run.duplicate(true)
	var history_size = flow.edit_history.undo_stack.size()
	var result = flow.start_combat()
	_check(not result.ok and flow.screen_state == "SHOP_PREPARE", "simulation failure does not enter playback")
	_check(flow.run == before and flow.run.rng.combat == before.rng.combat, "simulation failure preserves exact run and combat RNG")
	_check(flow.edit_history.undo_stack.size() == history_size, "simulation failure preserves preparation undo history")

func _read_cross_process_fixture():
	var expected = JSON.parse_string(FileAccess.get_file_as_string(base + "expected.json"))
	_check(expected is Dictionary, "cross process expected fixture exists")
	var flow = GameFlow.new(db, SaveService.new(base))
	_check(flow.continue_run().ok, "cross process continue actual save")
	_check(flow.run == expected and flow.screen_state == "SHOP_PREPARE", "cross process restored exact run not regenerated shop")
	_check(flow.run.pending_rewards[0].entry.craft_tier == 1 and flow.run.pending_rewards[0].entry.materials.size() == 2, "cross process pending metadata retained")
	_check(flow.run.health == 63.0 and flow.run.gold == 37, "cross process sustained resources")
	_check(flow.handle_pending(0, "storage").ok and flow.run.build.storage.back().uid == "persisted_pending", "cross process pending resolves stable instance")
	var corrupted = FileAccess.open(base + "run.save", FileAccess.WRITE)
	corrupted.store_string(JSON.stringify({"payload": "{}", "sha256": "fixture_corrupt_primary"}))
	corrupted.close()
	var recovery_saves = SaveService.new(base)
	var recovery = GameFlow.new(db, recovery_saves)
	_check(recovery.continue_run().ok and recovery_saves.notices.has("save_backup_recovered"), "cross process previous primary backup recovers actual flow")
	_check(recovery.run.pending_rewards[0].entry.uid == "persisted_pending" and recovery.run.health == 63.0, "cross process backup preserves prior pending state")
	var migration_saves = SaveService.new(base + "cross_migration/")
	var migrated = GameFlow.new(db, migration_saves)
	_check(migrated.continue_run().ok and migrated.run.schema_version == 2 and migrated.run.health == 63.0, "separate process migrates previous schema and continues actual flow")
	_check(migrated.run.pending_rewards[0].entry.materials.size() == 2 and FileAccess.file_exists(base + "cross_migration/run_before_migration_v1.save"), "cross migration pending provenance and original file retained")

func _finish():
	print("FLOW_CONTRACT_TESTS " + JSON.stringify({"phase": phase, "base": base, "checks": checks, "failures": failures, "ok": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
