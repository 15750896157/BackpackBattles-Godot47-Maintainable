extends SceneTree

var checks = 0
var failures: Array = []
var db
var tools

class RestrictedDB:
	extends RefCounted
	var base
	func _init(content): base = content
	func rows(table): return base.rows(table)
	func get_row(table, id):
		var row = base.get_row(table, id)
		if table == "enemy_builds" and id == "rust_scout_a": row["difficulty_min"] = "advanced"
		return row
	func list_values(value): return ContentDB.list_values(value)
	func parse_params(value): return ContentDB.parse_params(value)

func _init(): call_deferred("run")

func check(value: bool, name: String):
	checks += 1
	if not value: failures.append(name); printerr("QUALITY_RULE_FAIL ", name)

func context(act: int = 1, difficulty: String = "standard", loadout: String = "armorer_blades") -> Dictionary:
	return {"act": act, "step": 1, "difficulty_id": difficulty, "loadout_id": loadout, "completed_nodes": [], "events_seen": [], "rng": {"route": 67731}}

func run():
	db = ContentDB.new(); tools = PvEDeveloperToolService.new(db)
	var player = tools.loadout_snapshot("armorer_blades")
	var enemy = tools.opponent_snapshot("rust_scout_a")
	check(player.ok and enemy.ok, "authored snapshots load")
	_bad_snapshots(player, enemy)
	_passives(player, enemy)
	_starvation(player)
	_encounters()
	_tools(player, enemy)
	var sources: Dictionary = {}
	for path in ["combat/CombatEngine.gd", "combat/SnapshotBuilder.gd", "run/EncounterDirector.gd", "tools/DeveloperToolService.gd", "tools/DeveloperTools.gd"]:
		sources[path] = FileAccess.get_file_as_string("res://PvE/Rules/" + path).sha256_text()
	var result = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "source_sha256": sources, "content_sha256": db.content_sha256}
	var file = FileAccess.open("res://quality_rule_tests.json", FileAccess.WRITE); file.store_string(JSON.stringify(result, "\t")); file.close()
	print("QUALITY_RULE_TESTS ", JSON.stringify(result)); quit(0 if failures.is_empty() else 1)

func _bad_snapshots(player: Dictionary, enemy: Dictionary):
	var cases: Array = []
	var invalid = player.duplicate(true); invalid.base_stats.max_health = INF; cases.append(invalid)
	invalid = player.duplicate(true); invalid.base_stats.health = NAN; cases.append(invalid)
	invalid = player.duplicate(true); invalid.base_stats.stamina_max = -1; cases.append(invalid)
	invalid = player.duplicate(true); invalid.base_stats.health = float(player.base_stats.max_health) + 1; cases.append(invalid)
	invalid = player.duplicate(true); invalid.items = ["not a dictionary"]; cases.append(invalid)
	invalid = player.duplicate(true); invalid.items[0].cooldown = INF; cases.append(invalid)
	invalid = player.duplicate(true); invalid.items[0].effects = ["bad effect"]; cases.append(invalid)
	invalid = player.duplicate(true); invalid.items[0].relations = {"adjacent_4": "bad array"}; cases.append(invalid)
	invalid = player.duplicate(true); invalid.items[0].instance_id = "__boss__"; cases.append(invalid)
	invalid = player.duplicate(true); invalid.items[0].static_modifiers = [{"stat": "damage_flat", "value": NAN}]; cases.append(invalid)
	invalid = player.duplicate(true); invalid.passives = [1]; cases.append(invalid)
	invalid = player.duplicate(true); invalid.boss_phases = [{"phase": 2}]; cases.append(invalid)
	for index in cases.size():
		var original = var_to_bytes(cases[index])
		var result = CombatEngine.new(db).simulate(cases[index], enemy, 1)
		check(not result.ok and not str(result.error).is_empty(), "reject malformed snapshot %d without runtime exception" % index)
		check(var_to_bytes(cases[index]) == original, "malformed snapshot remains untouched %d" % index)
	check(not tools.validate_import({"snapshot": "bad"}).ok, "import rejects non-dictionary nested snapshot")
	invalid = player.duplicate(true); invalid.bags = ["bad"]
	check(not tools.validate_import(invalid).ok, "import rejects malformed bag entry")
	invalid = player.duplicate(true); invalid.items[0].origin = [0.5, 0]
	check(not tools.validate_import(invalid).ok, "import rejects fractional grid origins")

func _passives(player: Dictionary, enemy: Dictionary):
	var reference = CombatEngine.new(db).simulate(player, enemy, 217)
	var renamed = player.duplicate(true); renamed.passives[0].id = "renamed_generic_shape_passive"
	var result = CombatEngine.new(db).simulate(renamed, enemy, 217)
	var old_events = reference.full_events.filter(func(event): return str(event.source).begins_with("__passive__:") and event.type == "MODIFIER_APPLIED")
	var new_events = result.full_events.filter(func(event): return str(event.source).begins_with("__passive__:") and event.type == "MODIFIER_APPLIED")
	check(not old_events.is_empty() and new_events.size() == old_events.size(), "shape passive behavior is configured independently of definition ID")
	check(result.player_remaining_health == reference.player_remaining_health and result.enemy_remaining_health == reference.enemy_remaining_health, "renamed configured shape passive has identical combat values")
	var alchemist = tools.loadout_snapshot("alchemist_toxin"); alchemist.base_stats.health = 80
	reference = CombatEngine.new(db).simulate(alchemist, enemy, 271)
	renamed = alchemist.duplicate(true); renamed.passives[0].id = "renamed_generic_status_passive"
	result = CombatEngine.new(db).simulate(renamed, enemy, 271)
	old_events = reference.full_events.filter(func(event): return str(event.source).begins_with("__passive__:") and event.type == "HEAL")
	new_events = result.full_events.filter(func(event): return str(event.source).begins_with("__passive__:") and event.type == "HEAL")
	check(not old_events.is_empty() and new_events.size() == old_events.size(), "first-negative-status passive is configured independently of definition ID")
	check(result.total_healing == reference.total_healing, "renamed status passive preserves healing")

func _encounters():
	var director = EncounterDirector.new(db)
	for difficulty in ["standard", "challenge_3", "challenge_4", "challenge_5"]:
		for act in [1, 2, 3]:
			var card = director.make_card(context(act, difficulty), "elite_combat", DeterministicRNG.new(67731), 4)
			var expected = 2 if difficulty in ["challenge_4", "challenge_5"] and act >= 2 else 1
			check(card.affix_ids.size() == expected, "cumulative elite affix count %s act%d" % [difficulty, act])
			var snapshot = SnapshotBuilder.new(db).enemy(card.enemy_id, difficulty, card.affix_ids)
			check(snapshot.ok and snapshot.encounter_modifiers.size() == expected, "all previewed affixes enter snapshot %s act%d" % [difficulty, act])
	var combined = SnapshotBuilder.new(db).enemy("rust_scout_a", "standard", ["armored_start", "precision_opening", "armored_start"])
	check(combined.ok and combined.encounter_modifiers.size() == 2, "duplicate affix IDs do not stack twice")
	var profile = ProfileService.new(db)
	profile.on_combat({"current_node": {"type": "elite_combat", "enemy_id": "rust_scout_a", "affix_id": "armored_start", "affix_ids": ["armored_start", "precision_opening"]}}, {"winner_side": 1, "peak_armor": 0})
	check("armored_start" in profile.profile.seen_affixes and "precision_opening" in profile.profile.seen_affixes, "all encountered affixes are discovered in local profile")
	check(not SnapshotBuilder.new(db).enemy("rust_scout_a", "standard", ["does_not_exist"]).ok, "unknown extra affix rejected")
	var run = context()
	check(director.generate_act(run).ok, "route generation succeeds")
	var first = run.route_plan[0][0]
	run.completed_nodes = [first.duplicate(true)]; run.step = 2
	var repeating = first.duplicate(true); repeating.step = 2
	run.route_plan[1][0] = repeating
	var candidates = director.candidates(run)
	check(candidates[0].enemy_id != first.enemy_id, "shown candidate avoids immediately repeated authored build")
	check(director.finalize_card(run, candidates[0]) == candidates[0], "selected encounter equals the complete previewed card")
	for loadout in db.rows("character_loadouts"):
		var state = context(1, "standard", loadout.id)
		var counters = db.list_values(db.get_row("character_archetypes", loadout.archetype_hint).counter_tags)
		for seed in range(1, 9):
			var card = director.make_card(state, "normal_combat", DeterministicRNG.new(seed), 2)
			var threats = db.list_values(db.get_row("enemy_builds", card.enemy_id).threat_tags)
			check(not counters.any(func(tag): return tag in threats), "early encounter avoids declared loadout counter %s seed%d" % [loadout.id, seed])
	var restricted = EncounterDirector.new(RestrictedDB.new(db))
	for seed in range(1, 9):
		var card = restricted.make_card(context(), "normal_combat", DeterministicRNG.new(seed), 3)
		check(card.enemy_id != "rust_scout_a", "enemy minimum difficulty enforced seed%d" % seed)

func _starvation(player: Dictionary):
	var hungry = player.duplicate(true)
	for item in hungry.items:
		item.stamina_cost = 100
		item.cooldown = 0.5
	var empty_enemy = tools.opponent_snapshot("rust_scout_a")
	empty_enemy.items = []; empty_enemy.passives = []; empty_enemy.encounter_modifiers = []
	var result = CombatEngine.new(db).simulate(hungry, empty_enemy, 1)
	var blocked = float(result.stamina_starvation_time[0])
	check(blocked > 0 and blocked <= float(result.elapsed_time), "simultaneous stamina starvation cannot exceed real combat duration")
	var individual: Array = []
	for row in result.item_stats_by_instance_id.values():
		if row.side == 0 and not str(row.instance_id).begins_with("__"): individual.append(float(row.stamina_starvation))
	check(individual.size() == 2 and individual.all(func(value): return is_equal_approx(value, blocked)), "overlapping per-item starvation windows count once for actor")

func _tools(player: Dictionary, enemy: Dictionary):
	for row in db.rows("items") + db.rows("bags"):
		var result = tools.inspect_definition(row.id)
		check(result.ok and result.asset_exists and not result.shape.is_empty(), "definition inspector shape/text/reference " + str(row.id))
	var source = JSON.stringify(player)
	var uid = str(player.items[0].instance_id)
	var moved = tools.edit_snapshot(player, uid, 0, 1, 0)
	check(moved.ok and moved.snapshot.items.any(func(entry): return entry.instance_id == uid and entry.origin == [0, 1]), "editor applies legal position using production placement")
	check(JSON.stringify(player) == source, "editor leaves source snapshot immutable")
	check(not tools.edit_snapshot(player, uid, 8, 6, 0).ok, "editor rejects placement outside provided bags")
	var draft = tools.export_enemy(enemy)
	check(draft.ok and not draft.item_rows.is_empty() and not draft.bag_rows.is_empty(), "enemy draft exports definition and layout tables")
	check(tools.validate_import(draft).ok, "exported enemy draft imports without data loss")
	var path = "user://quality_enemy_definition.tres"
	check(ResourceSaver.save(EnemyBuildDefinition.new(draft.definition), path) == OK, "enemy definition exports real Godot Resource")
	var loaded = load(path)
	check(loaded is EnemyBuildDefinition and loaded.id == enemy.owner_id, "exported enemy Resource reloads")
	var result = tools.batch(player, enemy, 67731, 3)
	var again = tools.batch(player, enemy, 67731, 3)
	check(result.ok and result.count == 3 and result.runs == again.runs, "batch simulator deterministically replays exact snapshots and seeds")
	check(not tools.batch(player, enemy, 1, 0).ok and not tools.batch(player, enemy, 1, 2001).ok, "batch size limits validated")
