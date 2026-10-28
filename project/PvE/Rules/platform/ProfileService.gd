class_name ProfileService
extends RefCounted

var db
var profile: Dictionary
var platform

func _init(content = null, data: Dictionary = {}):
	db = content
	profile = data
	var defaults = {"schema_version": 2, "stats": {}, "unlocks": ["armorer", "alchemist", "armorer_blades", "armorer_guard", "alchemist_toxin", "alchemist_ember", "tutorial", "standard"], "seen_items": [], "seen_enemies": [], "seen_events": [], "seen_affixes": [], "recipes": [], "achievements": [], "pending_platform_achievements": [], "tutorial_completed": [], "run_history": [], "character_clears": {}, "runs_started": 0}
	for key in defaults:
		if not profile.has(key): profile[key] = defaults[key].duplicate(true) if defaults[key] is Array or defaults[key] is Dictionary else defaults[key]
	for row in db.rows("stat_definitions"):
		if not profile.stats.has(row.id): profile.stats[row.id] = row.default_value
	platform = PlatformService.new(profile)

func _add_unique(key: String, value: String):
	if value not in profile[key]: profile[key].append(value)

func discover(id: String):
	if db.get_row("items", id).is_empty() and db.get_row("bags", id).is_empty(): return
	_add_unique("seen_items", id)
	var item_count = 0
	for seen in profile.seen_items:
		if not db.get_row("items", seen).is_empty(): item_count += 1
	profile.stats.items_discovered = item_count
	check_achievements()

func recipe(id: String, crafted: bool = false):
	_add_unique("recipes", id)
	profile.stats.recipes_discovered = profile.recipes.size()
	if crafted:
		profile.stats.recipes_crafted = int(profile.stats.recipes_crafted) + 1
		if int(db.get_row("recipes", id).get("tier", 1)) == 2: profile.stats.tier2_recipes_crafted = int(profile.stats.tier2_recipes_crafted) + 1
	check_achievements()

func on_combat(run: Dictionary, result: Dictionary):
	var stats: Dictionary = profile.stats
	var node: Dictionary = run.current_node
	var id = str(node.get("boss_id", "")) if not str(node.get("boss_id", "")).is_empty() else str(node.get("enemy_id", ""))
	_add_unique("seen_enemies", id)
	var affixes = db.list_values(node.get("affix_ids", []))
	if affixes.is_empty(): affixes = db.list_values(node.get("affix_id", ""))
	for affix in affixes:
		if not db.get_row("encounter_affixes", str(affix)).is_empty(): _add_unique("seen_affixes", str(affix))
	stats.max_armor = maxf(float(stats.get("max_armor", 0)), float(result.get("peak_armor", 0)))
	stats.max_combat_healing = maxf(float(stats.get("max_combat_healing", 0)), float(result.get("total_healing", 0)))
	stats.max_used_cells = maxi(int(stats.get("max_used_cells", 0)), int(result.get("used_cells", 0)))
	stats["max_trigger_depth"] = maxi(int(stats.get("max_trigger_depth", 0)), int(result.get("max_trigger_depth", 0)))
	stats["max_damage"] = maxf(float(stats.get("max_damage", 0)), float(result.get("max_damage", 0)))
	if int(result.winner_side) == 0:
		if is_equal_approx(float(result.player_remaining_health), 1.0): stats.wins_at_one_health = int(stats.wins_at_one_health) + 1
		if node.type == "boss":
			stats.fastest_boss_seconds = minf(float(stats.fastest_boss_seconds), float(result.elapsed_time))
			var damage = str(result.get("final_damage_type", ""))
			if damage == "poison": stats.boss_kill_poison = int(stats.boss_kill_poison) + 1
			if damage == "burn": stats.boss_kill_burn = int(stats.boss_kill_burn) + 1
			unlock_matching("boss_kill", id)
	check_achievements(run)

func unlock_matching(requirement: String, id: String):
	for row in db.rows("unlock_rules"):
		if row.requirement_type == requirement and str(row.requirement_params) == id: _add_unique("unlocks", row.target_id)

func on_run_ended(run: Dictionary, clear: bool):
	if bool(run.get("profile_result_recorded", false)): return
	run["profile_result_recorded"] = true
	if clear:
		profile.stats.runs_cleared = int(profile.stats.runs_cleared) + 1
		var character_stat = str(run.character_id) + "_clears"
		profile.stats[character_stat] = int(profile.stats.get(character_stat, 0)) + 1
		var level = int(str(run.difficulty_id).trim_prefix("challenge_")) if str(run.difficulty_id).begins_with("challenge_") else 0
		profile.stats.highest_challenge_clear = maxi(int(profile.stats.highest_challenge_clear), level)
		if run.difficulty_id == "standard" and int(run.get("refreshes_total", 0)) == 0: profile.stats.standard_clear_no_refresh = int(profile.stats.standard_clear_no_refresh) + 1
		if not profile.character_clears.has(run.character_id): profile.character_clears[run.character_id] = []
		if run.difficulty_id not in profile.character_clears[run.character_id]: profile.character_clears[run.character_id].append(run.difficulty_id)
		for row in db.rows("unlock_rules"):
			if row.requirement_type == "run_clear" and db.parse_params(row.requirement_params).get("difficulty", "") == run.difficulty_id: _add_unique("unlocks", row.target_id)
	profile.run_history.append({"run_id": run.run_id, "character_id": run.character_id, "difficulty_id": run.difficulty_id, "seed": run.run_seed, "clear": clear, "act": run.act, "nodes": run.completed_nodes.size(), "elapsed": run.get("play_seconds", 0)})
	if profile.run_history.size() > 100: profile.run_history.pop_front()
	check_achievements(run)

func check_achievements(run: Dictionary = {}):
	for row in db.rows("achievements"):
		var value = float(profile.stats.get(row.stat_key, 0))
		if row.stat_key == "run_interest_gold": value = float(run.get("interest_total", 0))
		var unlocked = value >= float(row.target_value) if row.comparison == ">=" else value <= float(row.target_value)
		if unlocked and row.id not in profile.achievements:
			_add_unique("achievements", row.id)
			platform.unlock(row.steam_api_name)
