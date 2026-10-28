extends SceneTree

var checks := 0
var failures: Array = []
var db
var EngineClass = preload("res://PvE/Rules/combat/CombatEngine.gd")
var BuilderClass = preload("res://PvE/Rules/combat/SnapshotBuilder.gd")
var QueueClass = preload("res://PvE/Rules/combat/CombatEventQueue.gd")
var StatusClass = preload("res://PvE/Rules/combat/StatusController.gd")

func _init(): call_deferred("run_tests")

func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)
		printerr("COMBAT_TEST_FAIL ", name)

func effect(kind: String, value: String, trigger: String = "cooldown_ready", target: String = "enemy", extra: Dictionary = {}) -> Dictionary:
	var row = {"id": kind + "_" + value + "_" + trigger, "sequence": 1, "trigger_id": trigger, "effect_type": kind,
		"effect_params": value, "target_selector": target, "condition_id": "always", "internal_cooldown": 0.0,
		"spatial_template_id": "none", "chain_depth_cost": 1}
	row.merge(extra, true)
	return row

func item(id: String, effects: Array, cooldown: float = 0.5, extra: Dictionary = {}) -> Dictionary:
	var row = {"instance_id": id, "def_id": id, "effects": effects, "cooldown": cooldown, "stamina_cost": 0.0,
		"tags": ["weapon"], "shape_id": "shape_1", "x": 0, "y": 0, "relations": {}}
	row.merge(extra, true)
	return row

func snapshot(items: Array, health: float = 30.0, extra: Dictionary = {}) -> Dictionary:
	var row = {"snapshot_version": 2, "content_version": db.content_version, "owner_id": "fixture",
		"base_stats": {"health": health, "max_health": health, "crit_chance": 0.0, "crit_multiplier": 1.5,
			"stamina_max": 10.0, "stamina_regen": 1.0, "damage_scalar": 1.0, "status_scalar": 1.0},
		"items": items, "passives": [], "bag_effects": [], "encounter_modifiers": [], "boss_phases": []}
	row.merge(extra, true)
	return row

func events(result: Dictionary, type: String) -> Array:
	return result.full_events.filter(func(v): return str(v.type) == type)

func run_tests() -> void:
	db = ContentDB.new()
	check(db.errors.is_empty(), "content loads")
	_test_queue()
	_test_statuses()
	_test_determinism()
	_test_preview()
	_test_damage()
	_test_fatigue()
	_test_effects()
	_test_reactions()
	_test_all_triggers()
	_test_limits_and_affixes()
	_test_snapshot_content()
	_test_real_special_bag()
	var module_hashes: Dictionary = {}
	for path in ["SnapshotBuilder.gd", "CombatEngine.gd", "CombatEventQueue.gd", "EffectResolver.gd", "StatusController.gd"]:
		module_hashes[path] = FileAccess.get_file_as_string("res://PvE/Rules/combat/" + path).sha256_text()
	var report = {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string,
		"content_sha256": db.content_sha256, "module_sha256": module_hashes}
	var path = "res://tests/combat_test_results.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("COMBAT_TEST_RESULTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_queue() -> void:
	var queue = QueueClass.new(db)
	check(queue.push({"event_id": "same", "tick": 1, "priority": 1, "side": 0, "source_id": "b", "depth": 0}), "queue accepts event")
	check(not queue.push({"event_id": "same", "tick": 0, "depth": 0}), "queue dedup event id")
	queue.push({"event_id": "second", "tick": 1, "priority": 1, "side": 0, "source_id": "a", "depth": 0})
	check(str(queue.pop_due(1).event_id) == "second", "queue stable source ordering")
	check(not queue.push({"event_id": "depth", "depth": 9}), "queue rejects depth above 8")
	check(queue.rejected.size() == 1, "queue reports depth rejection")
	var generated = QueueClass.new(db)
	check(not generated.push({"depth": 9}), "generated event ID rejection recorded")
	check(generated.push({"depth": 0}), "generated IDs remain unique after rejected event")

func _test_preview() -> void:
	var blade = item("blade", [effect("physical_damage", "value:4")], 2.0)
	var stone = item("stone", [effect("modify_damage_flat", "value:2", "combat_start", "spatial_targets", {"spatial_template_id": "adjacent"}),
		effect("modify_cooldown_pct", "value:-0.08", "combat_start", "spatial_targets", {"spatial_template_id": "adjacent", "sequence": 2})], 0.0,
		{"relations": {"adjacent": ["blade"]}, "tags": ["tool"]})
	var pouch = item("pouch", [effect("gain_gold", "value:3", "combat_start", "self")], 0.0)
	var player = snapshot([blade, stone, pouch])
	var original = JSON.stringify(player)
	var engine = EngineClass.new(db)
	var result = engine.preview(player)
	check(result.ok and result.tick == 0 and result.items.size() == 3, "preview settles only tick zero")
	check(result.items.blade.base_cooldown == 2.0 and is_equal_approx(result.items.blade.cooldown, 1.84), "preview uses combat cooldown formula")
	check(result.items.blade.base_damage == 4.0 and result.items.blade.damage == 6.0, "preview applies spatial opening damage")
	check(result.items.stone.damage == 0.0 and result.items.blade.modifiers.size() == 2, "preview nonweapon damage stays zero and exposes modifiers")
	check(JSON.stringify(player) == original and result.excludes.has("run_deltas"), "preview leaves snapshot and economy uncommitted")
	var foe = snapshot([])
	var after_preview = engine.simulate(player, foe, 6751)
	check(after_preview.replay_digest == EngineClass.new(db).simulate(player, foe, 6751).replay_digest, "preview cannot alter later seeded combat")
	var blocked = item("blocked", [effect("physical_damage", "value:10", "cooldown_ready", "enemy", {"condition_id": "spatial_target_count", "condition_params": "min:1", "spatial_template_id": "front_1"})])
	result = engine.preview(snapshot([blocked]))
	check(result.items.blocked.damage == 10.0 and not result.items.blocked.can_deal_damage and result.items.blocked.damage_when_conditions_met == 0.0, "preview exposes unmet spatial damage conditions")

func _test_statuses() -> void:
	var controller = StatusClass.new(db)
	var actor = {"statuses": {}}
	for id in ["poison", "burn", "slow", "regeneration", "lifesteal", "vulnerable", "haste", "fortified"]:
		var applied = controller.apply(actor, id, 1000, 1.0, 0, 0.05, "s", 0)
		check(applied.added == int(controller.definition(id).stack_cap), "status cap " + id)
	var due = controller.due(actor, 10, 0.05)
	check(due.any(func(v): return v.status_id == "burn" and v.amount == 49), "burn half-stack tick")
	check(controller.stacks(actor, "burn") == 98, "burn decays one stack")
	controller.due(actor, 20, 0.05)
	check(controller.stacks(actor, "haste") == 0, "timed status expires")
	check(controller.stacks(actor, "poison") == 98, "poison duration ignored for decay model")
	var removed = controller.remove(actor, "negative", 4)
	check(removed == 4, "cleanse removes exactly requested negative stacks")

func _test_determinism() -> void:
	var player = snapshot([item("b", [effect("physical_damage", "value:5")]), item("a", [effect("gain_armor", "value:3", "cooldown_ready", "self")])])
	var enemy = snapshot([item("enemy", [effect("physical_damage", "value:4")])])
	var original = JSON.stringify(player)
	var engine = EngineClass.new(db)
	var first = engine.simulate(player, enemy, 91237)
	var second = engine.simulate(player, enemy, 91237)
	check(first.replay_digest == second.replay_digest, "fixed seed replay digest")
	check(first.rng_final_state == second.rng_final_state, "fixed seed rng state")
	check(JSON.stringify(player) == original, "snapshot remains immutable")
	player.items.reverse()
	var reordered = engine.simulate(player, enemy, 91237)
	check(first.replay_digest == reordered.replay_digest, "item input order irrelevant")
	var outdated = snapshot([])
	outdated["content_sha256"] = "old_content"
	check(not engine.simulate(outdated, enemy, 1).ok, "outdated content hash rejected")
	check(not engine.preview(outdated).ok, "outdated preview content rejected")
	check(first.timeline.size() <= 500 and first.timeline[-1].time == first.elapsed_time, "timeline bounded and final frame retained")

func _test_damage() -> void:
	var player = snapshot([item("attack", [effect("physical_damage", "value:10")])])
	var enemy = snapshot([item("armor", [effect("gain_armor", "value:12", "combat_start", "self")], 0.0)], 10)
	var result = EngineClass.new(db).simulate(player, enemy, 1)
	check(events(result, "PHYSICAL_DAMAGE")[0].value == 0.0 and events(result, "PHYSICAL_DAMAGE")[0].armor_absorbed == 10.0, "physical armor absorbs before life")
	player.items[0].effects = [effect("true_damage", "value:10")]
	result = EngineClass.new(db).simulate(player, enemy, 1)
	check(result.elapsed_time == 0.5 and result.winner_side == 0, "true damage ignores armor")
	var retaliator = snapshot([item("counter", [effect("physical_damage", "value:100", "damage_taken")], 0.0)], 1)
	result = EngineClass.new(db).simulate(player, retaliator, 1)
	check(result.player_remaining_health == 30 and result.winner_side == 0, "death interrupts lethal defender reactions")
	var hungry = snapshot([item("hungry", [effect("physical_damage", "value:2")], 0.5, {"stamina_cost": 11.0})])
	result = EngineClass.new(db).simulate(hungry, snapshot([]), 1)
	check(not events(result, "STAMINA_WAIT").is_empty() and result.stamina_starvation_time[0] > 0, "stamina shortage retries")

func _test_fatigue() -> void:
	var result = EngineClass.new(db).simulate(snapshot([], 10), snapshot([], 10), 1)
	check(result.winner_side == 1 and result.defeat_reason == "simultaneous_death", "simultaneous death player loss")
	check(result.elapsed_time == 89.0, "fatigue at85 then4at87 and7at89")
	check(events(result, "FATIGUE_DAMAGE").size() == 4, "fatigue is bilateral atom")

func _test_effects() -> void:
	var rows = [effect("gain_gold", "value:2", "combat_start", "self"), effect("free_refresh", "value:1", "combat_start", "self"), effect("max_health", "value:5", "combat_start", "self")]
	for index in rows.size(): rows[index].id += str(index)
	var result = EngineClass.new(db).simulate(snapshot([item("economy", rows, 0.0)]), snapshot([], 5), 1)
	check(result.run_deltas.gold == 2 and result.run_deltas.free_refresh == 1 and result.run_deltas.max_health == 5, "all noncombat effects returned as run deltas")
	var modifier_rows = [effect("modify_damage_flat", "value:3", "combat_start", "source_item"), effect("modify_crit_chance", "value:0.2", "combat_start", "source_item"), effect("modify_status_power", "value:0.5", "combat_start", "source_item"), effect("modify_cooldown_pct", "value:-0.5", "combat_start", "source_item"), effect("physical_damage", "value:4")]
	for index in modifier_rows.size(): modifier_rows[index].id += str(index)
	result = EngineClass.new(db).simulate(snapshot([item("modified", modifier_rows, 1.0)]), snapshot([], 100), 777)
	check(events(result, "MODIFIER_APPLIED").size() == 4 and events(result, "PHYSICAL_DAMAGE")[0].time == 0.5, "four modifier templates and minimum cooldown")
	var statuses_rows = [effect("apply_status", "value:poison:5", "combat_start", "self"), effect("convert_status", "from:poison|to:regeneration|ratio:1", "combat_start", "self"), effect("remove_status", "status_id:regeneration|stacks:2", "combat_start", "self"), effect("gain_stamina", "value:-3", "combat_start", "self"), effect("heal", "value:5", "combat_start", "self")]
	for index in statuses_rows.size(): statuses_rows[index].sequence = index
	result = EngineClass.new(db).simulate(snapshot([item("status", statuses_rows, 0.0)]), snapshot([], 10), 1)
	check(events(result, "STATUS_REMOVED").any(func(v): return v.value == 2), "convert and remove status templates")
	check(events(result, "STAMINA_CHANGED")[0].value == -3.0, "negative gain stamina consumes")
	check(events(result, "HEAL")[0].overheal == 5.0, "overheal explicitly accounted")
	var regen = item("regen", [effect("modify_status_power", "value:1", "combat_start", "source_item"),
		effect("apply_status", "value:regeneration:3", "combat_start", "self", {"sequence": 2})], 0.0)
	var regen_player = snapshot([regen], 100)
	regen_player.base_stats.health = 50
	result = EngineClass.new(db).simulate(regen_player, snapshot([], 100), 1)
	check(events(result, "HEAL")[0].value == 6.0, "regeneration status power applied once to stacks")

func _test_reactions() -> void:
	var deep_chain: Array = []
	for index in 5:
		var row = effect("advance_cooldown", "value:1", "cooldown_ready", "spatial_targets", {"spatial_template_id": "adjacent_4", "chain_depth_cost": 1 if index == 0 else 2})
		deep_chain.append(item("chain_" + str(index), [row], 0.5 if index == 0 else 1.5,
			{"relations": {"adjacent_4": ["chain_" + str(index + 1)]}, "x": index}))
	deep_chain.append(item("chain_5", [effect("physical_damage", "value:1")], 1.5, {"x": 5}))
	var depth_result = EngineClass.new(db).simulate(snapshot(deep_chain, 10), snapshot([], 10), 1)
	check(events(depth_result, "CHAIN_LIMIT_REACHED").any(func(v): return int(v.depth) == 9), "real relay chain rejects ninth-depth effect")
	check(depth_result.full_events.all(func(v): return v.type == "CHAIN_LIMIT_REACHED" or int(v.depth) <= 8), "real relay chain only executes depth at most eight")
	var rows = [effect("gain_armor", "value:2", "armor_gained", "self", {"condition_id": "trigger_count_max", "condition_params": "3"})]
	var result = EngineClass.new(db).simulate(snapshot([item("starter", [effect("gain_armor", "value:1", "combat_start", "self")], 0.0), item("loop", rows, 0.0)]), snapshot([], 10), 1)
	check(events(result, "CHAIN_LIMIT_REACHED").any(func(v): return v.reason == "same_item_same_root"), "reactive loop blocked within root")
	var passive = db.get_row("character_passives", "armorer_shape_mastery")
	var weapons = []
	for index in 4:
		weapons.append(item("w" + str(index), [effect("physical_damage", "value:1")], 0.5, {"shape_id": "shape_" + str(index), "x": index}))
	result = EngineClass.new(db).simulate(snapshot(weapons, 30, {"passives": [passive]}), snapshot([], 500), 123)
	check(events(result, "MODIFIER_APPLIED").filter(func(v): return str(v.source).begins_with("__passive__:")).size() == 3, "armorer distinct shape cap3")
	var alchemist = db.get_row("character_passives", "alchemist_first_reaction")
	var status_items = [item("p", [effect("apply_status", "value:poison:1")]), item("b", [effect("apply_status", "value:burn:1")]), item("s", [effect("apply_status", "value:slow:1")]), item("v", [effect("apply_status", "value:vulnerable:1")])]
	result = EngineClass.new(db).simulate(snapshot(status_items, 30, {"passives": [alchemist]}), snapshot([], 100), 1)
	check(events(result, "HEAL").filter(func(v): return str(v.source).begins_with("__passive__:")).size() == 3, "alchemist unique negative cap3")

func _test_snapshot_content() -> void:
	var builder = BuilderClass.new(db)
	var valid = 0
	for row in db.rows("enemy_builds"):
		var built = builder.enemy(str(row.id), "standard")
		check(built.get("ok", false), "enemy snapshot " + str(row.id))
		if built.get("ok", false): valid += 1
	check(valid > 20, "all enemy templates covered")
	for row in db.rows("bosses"):
		var built = builder.boss(str(row.id), "standard")
		check(built.get("ok", false) and built.boss_phases.size() == 2, "boss snapshot " + str(row.id))
		if built.get("ok", false):
			var result = EngineClass.new(db).simulate(snapshot([item("strong", [effect("physical_damage", "value:25")], 1.0)], 1000), built, 818)
			check(not events(result, "BOSS_PHASE_TELEGRAPH").is_empty() and result.boss_phases[1] == 2, "boss phase telegraph " + str(row.id))
			if str(row.id) == "boss_star_regent":
				var buffs = events(result, "MODIFIER_APPLIED").filter(func(v): return v.source == "__boss__")
				check(not buffs.is_empty() and buffs.all(func(v): return v.target_instance_id == "s2"), "star regent periodically buffs actual weapon rather than healing tool")
			var enabled = events(result, "ITEM_ACTIVATED").filter(func(v): return v.source_side == 1 and str(v.source) == str(built.items[-1].instance_id))
			if not enabled.is_empty():
				var phase_events = events(result, "BOSS_PHASE")
				check(enabled[0].time >= phase_events[0].time, "phase2 item cannot activate early " + str(row.id))

func _test_real_special_bag() -> void:
	var build = {"width": 9, "height": 7, "bags": [{"uid": "gear_bag", "definition_id": "bag_gear_sling", "x": 0, "y": 0, "rotation": 0}],
		"items": [{"uid": "star_cover", "definition_id": "utility_knife", "x": 2, "y": 1, "rotation": 0},
			{"uid": "star_neighbor", "definition_id": "utility_knife", "x": 1, "y": 1, "rotation": 0},
			{"uid": "star_far", "definition_id": "utility_knife", "x": 0, "y": 0, "rotation": 0}], "storage": [], "storage_capacity": 2}
	var player = BuilderClass.new(db).player({"run_id": "special_bag", "character_id": "armorer", "health": 105, "max_health": 105, "build": build})
	check(player.ok and player.content_sha256 == db.content_sha256, "real gear sling snapshot valid and identifies exact content")
	var preview = EngineClass.new(db).preview(player)
	check(preview.ok and is_equal_approx(preview.items.star_cover.cooldown, 2.28), "gear sling star coverage reduces cooldown5pct")
	check(is_equal_approx(preview.items.star_neighbor.cooldown, 2.28) and preview.items.star_neighbor.modifiers.size() == 1, "gear sling star orthogonal neighbor gains exactly one modifier")
	check(is_equal_approx(preview.items.star_far.cooldown, 2.4), "same bag distant item gets no star effect")
	var result = EngineClass.new(db).simulate(player, snapshot([], 500), 1)
	var attacks = events(result, "PHYSICAL_DAMAGE")
	check(attacks.filter(func(v): return v.source == "star_cover")[0].time == 2.3 and attacks.filter(func(v): return v.source == "star_neighbor")[0].time == 2.3,
		"real gear sling advances both affected first attacks to2.30 fixed step")
	check(attacks.filter(func(v): return v.source == "star_far")[0].time == 2.4, "unaffected real knife first attack remains2.40")

func _test_all_triggers() -> void:
	var crit_player = snapshot([item("attack", [effect("physical_damage", "value:2")]), item("hit", [effect("gain_armor", "value:1", "attack_hit", "self")], 0.0), item("crit", [effect("gain_stamina", "value:1", "critical_hit", "self")], 0.0)])
	crit_player.base_stats.crit_chance = 0.75
	var result = EngineClass.new(db).simulate(crit_player, snapshot([], 50), 1)
	check(events(result, "ARMOR_GAINED").any(func(v): return v.source == "hit"), "attack_hit observes friendly weapon")
	check(events(result, "STAMINA_CHANGED").any(func(v): return v.source == "crit"), "critical_hit trigger")
	var relay = item("relay", [effect("advance_cooldown", "seconds:0.8", "target_activated", "spatial_targets", {"spatial_template_id": "adjacent_4"})], 0.0, {"relations": {"adjacent_4": ["attack"]}})
	result = EngineClass.new(db).simulate(snapshot([item("attack", [effect("physical_damage", "value:2")], 1.0), relay]), snapshot([], 50), 1)
	check(not events(result, "COOLDOWN_ADVANCED").is_empty(), "target_activated spatial relay")
	var counter = item("counter", [effect("true_damage", "value:1", "damage_taken")], 0.0)
	result = EngineClass.new(db).simulate(snapshot([item("attack", [effect("physical_damage", "value:2")])]), snapshot([counter]), 1)
	check(events(result, "TRUE_DAMAGE").any(func(v): return v.source == "counter"), "damage_taken trigger")
	var low = item("low", [effect("heal", "value:15", "first_low_health", "self", {"condition_id": "trigger_count_max", "condition_params": "1"})], 0.0)
	result = EngineClass.new(db).simulate(snapshot([low], 30), snapshot([item("enemy", [effect("true_damage", "value:5")], 1.0)], 100), 1)
	check(events(result, "HEAL").filter(func(v): return v.source == "low").size() == 1, "first_low_health only once")
	var periodic = item("periodic", [effect("gain_armor", "value:1|interval:1", "interval", "self")], 0.0)
	var fatigue = item("fatigue", [effect("modify_damage_flat", "value:4", "fatigue_start", "self")], 0.0)
	result = EngineClass.new(db).simulate(snapshot([periodic, fatigue], 10), snapshot([], 10), 1)
	check(events(result, "ARMOR_GAINED")[0].time == 1.0, "interval fixed clock")
	check(events(result, "MODIFIER_APPLIED").any(func(v): return v.source == "fatigue" and v.time == 85.0), "fatigue_start trigger")

func _test_limits_and_affixes() -> void:
	var player = snapshot([item("attack", [effect("physical_damage", "value:10")])])
	player.base_stats.crit_chance = 2.0
	var result = EngineClass.new(db).simulate(player, snapshot([], 10), 40000)
	check(not events(result, "PHYSICAL_DAMAGE")[0].critical, "crit chance capped at75 despite base200")
	var shield = item("fortified", [effect("apply_status", "value:fortified:99", "combat_start", "self")], 0.0)
	player.base_stats.crit_chance = 0.0
	result = EngineClass.new(db).simulate(player, snapshot([shield], 30), 1)
	check(events(result, "PHYSICAL_DAMAGE")[0].value == 6.0, "fortified capped 10 stacks reduces40pct")
	var slow = item("slow", [effect("apply_status", "value:slow:99", "combat_start")], 0.0)
	result = EngineClass.new(db).simulate(snapshot([slow], 10), snapshot([item("enemy", [effect("physical_damage", "value:1")], 1.0)]), 1)
	check(events(result, "PHYSICAL_DAMAGE")[0].time == 2.0, "slow progress reduction capped50pct")
	var huge_advance = item("relay", [effect("advance_cooldown", "value:10", "combat_start", "spatial_targets", {"spatial_template_id": "adjacent_4"})], 0.0, {"relations": {"adjacent_4": ["attack"]}})
	result = EngineClass.new(db).simulate(snapshot([item("attack", [effect("physical_damage", "value:1")], 2.0), huge_advance], 10), snapshot([], 10), 1)
	check(events(result, "COOLDOWN_ADVANCED")[0].value == 1.0, "cooldown advance per-target per-root capped1s")
	check(events(result, "CHAIN_LIMIT_REACHED").any(func(v): return v.reason == "cooldown_advance_cap"), "advance cap logged")
	var source_status = item("poison", [effect("apply_status", "value:poison:4")], 0.5)
	var echo = db.get_row("encounter_affixes", "status_echo")
	result = EngineClass.new(db).simulate(snapshot([], 100), snapshot([source_status], 100, {"encounter_modifiers": [echo]}), 1)
	var echoed = events(result, "STATUS_APPLIED").filter(func(v): return str(v.source).begins_with("__affix__:"))
	check(not echoed.is_empty() and echoed[0].target_side == 0, "status echo repeats on original recipient")
	check(echoed.size() <= 8, "status echo per-combat cap8")
	for affix_id in ["accelerated_opening", "armored_start", "reactive_armor", "healing_surge", "precision_opening", "thick_hide", "restless"]:
		var builder = BuilderClass.new(db)
		var built = builder.enemy("rust_scout_a", "standard", affix_id)
		var fight = EngineClass.new(db).simulate(snapshot([item("weapon", [effect("physical_damage", "value:3")], 1.0)], 80), built, 74217)
		check(fight.ok and not fight.full_events.is_empty(), "affix complete fight " + affix_id)
