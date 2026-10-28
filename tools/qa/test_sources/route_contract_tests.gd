extends SceneTree

var checks = 0
var failures: Array = []
var db
var director
var leaves = 0
var chapter_min = 99
var chapter_max = 0

func _init(): call_deferred("execute")

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures.append(message)
		if failures.size() <= 12: printerr("ROUTE_FAIL ", message)

func execute():
	db = ContentDB.new(); director = EncounterDirector.new(db)
	check(int(db.value("max_noncombat_nodes_per_act", 0)) == 1, "D02 explicit source rule limits noncombat nodes to one per act")
	for loadout in db.rows("character_loadouts"):
		for difficulty in db.rows("difficulty_levels"):
			for seed in range(1, 9):
				for act in range(1, 4):
					var run = {"act": act, "step": 1, "difficulty_id": str(difficulty.id), "loadout_id": str(loadout.id), "completed_nodes": [{"type": "boss", "act": act - 1}], "events_seen": [], "rng": {"route": seed}}
					check(director.generate_act(run).ok, "all difficulty/loadout/seed chapter plans generated")
					_walk(run, 0)
	check(chapter_min == 4 and chapter_max == 5, "every complete chapter is exactly four to five battles")
	var fallback_run = {"act": 1, "step": 1, "difficulty_id": "standard", "loadout_id": "armorer_blades", "completed_nodes": [], "events_seen": [], "rng": {"route": 1}}
	director.generate_act(fallback_run)
	fallback_run.step = 4
	fallback_run.completed_nodes = [{"type": "event"}]
	var rng = DeterministicRNG.new(99)
	fallback_run.route_plan[3] = [director.make_card(fallback_run, "rest", rng, 4), director.make_card(fallback_run, "merchant", rng, 4)]
	fallback_run.route_fallbacks[3] = [director.make_card(fallback_run, "normal_combat", rng, 4), director.make_card(fallback_run, "elite_combat", rng, 4)]
	var before = var_to_bytes(fallback_run)
	var first = director.candidates(fallback_run)
	check(first.size() == 2 and first.all(func(card): return str(card.type).ends_with("combat")), "both filtered legacy noncombat cards are replaced by real authored combat fallbacks")
	check(first == director.candidates(fallback_run) and var_to_bytes(fallback_run) == before, "fallback query stable and consumes neither route RNG nor input")
	check(not director.is_card_allowed(fallback_run, {"type": "event"}), "legacy completed cards without act still enforce current chapter cap")
	fallback_run.completed_nodes.append({"type": "boss"})
	check(director.is_card_allowed(fallback_run, {"type": "event"}), "legacy last Boss resets chapter cap")
	var valid = ContentValidator.new(db).validate()
	check(valid.ok and valid.warnings.is_empty() and valid.route_battle_range == {"min": 12.0, "max": 15.0}, "compiler and native validator agree on 12 to 15 with zero warnings")
	var result = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "chapter_paths": leaves, "chapter_battles": {"min": chapter_min, "max": chapter_max}, "full_run_battles": {"min": chapter_min * 3, "max": chapter_max * 3}, "loadouts": 4, "difficulties": 8, "seeds_per_combination": 8, "content_version": db.content_version, "content_sha256": db.content_sha256, "source_sha256": FileAccess.get_file_as_string("res://PvE/Rules/run/EncounterDirector.gd").sha256_text()}
	var file = FileAccess.open("res://route_contract_tests.json", FileAccess.WRITE); file.store_string(JSON.stringify(result, "\t")); file.close()
	print("ROUTE_CONTRACT_TESTS ", JSON.stringify(result)); quit(0 if failures.is_empty() else 1)

func _walk(run: Dictionary, battles: int):
	var original = var_to_bytes(run)
	var cards = director.candidates(run)
	if int(run.step) == 5:
		check(cards.size() == 1 and cards[0].type == "boss" and not str(cards[0].boss_id).is_empty(), "last step is the unique required chapter Boss")
		leaves += 1
		chapter_min = mini(chapter_min, battles + 1)
		chapter_max = maxi(chapter_max, battles + 1)
		check(battles + 1 >= 4 and battles + 1 <= 5, "every reachable chapter path satisfies D02")
		return
	check(cards.size() >= 2 and cards.size() <= 3, "each ordinary step has two to three reachable real choices")
	check(cards == director.candidates(run) and var_to_bytes(run) == original, "route display deterministic and input immutable")
	for card in cards:
		check(director.finalize_card(run, card) == card, "shown card and final selection identical")
		var fighting = str(card.type).ends_with("combat")
		if int(run.act) == 1 and int(run.step) <= 2 and fighting:
			var loadout = db.get_row("character_loadouts", str(run.loadout_id))
			var counters = db.list_values(db.get_row("character_archetypes", str(loadout.archetype_hint)).counter_tags)
			var threats = db.list_values(db.get_row("enemy_builds", str(card.enemy_id)).threat_tags)
			check(not counters.any(func(tag): return tag in threats), "first two route steps do not offer configured loadout counters")
		var next = run.duplicate(true)
		next.completed_nodes.append(card.duplicate(true))
		next.step = int(next.step) + 1
		_walk(next, battles + int(fighting))
