extends SceneTree

var checks = 0
var failures: Array = []
var samples: Dictionary = {}
func _init(): call_deferred("run")
func check(value: bool, name: String):
	checks += 1
	if not value: failures.append(name); printerr("RULE_TEXT_FAIL ", name)
func readable(text: String) -> bool:
	var codes = RegEx.new(); codes.compile("[a-z]+_[a-z_0-9]+")
	return not text.is_empty() and codes.search(text) == null and "未知" not in text and "Unknown" not in text
func run():
	var db = ContentDB.new(); var formatter = RuleText.new(db)
	for language in ["zh_CN", "en"]:
		for row in db.rows("items") + db.rows("bags"):
			var text = formatter.item(str(row.id), language)
			check(readable(text), "complete readable item " + str(row.id) + " " + language)
			samples[str(row.id) + ":" + language] = text
		for row in db.rows("encounter_affixes"):
			check(readable(formatter.affix(row, language)), "readable numerical affix " + str(row.id) + " " + language)
		for row in db.rows("bosses"):
			check(readable(formatter.boss(row.id, language)) and formatter.boss(row.id, language).contains("%"), "complete telegraphed boss stages " + str(row.id) + " " + language)
		for row in db.rows("statuses"):
			check(readable(formatter.status(row.id, language)) and readable(formatter.term("statuses", row.id, language)), "status rules and display name " + str(row.id) + " " + language)
		for row in db.rows("spatial_templates"):
			check(readable(formatter.spatial(row.id, language)) and readable(formatter.term("spatial_templates", row.id, language)), "all spatial terms " + str(row.id) + " " + language)
		for row in db.rows("trigger_templates"):
			check(readable(formatter.trigger(row.id, language)), "all trigger terms " + str(row.id) + " " + language)
		var examples = {"always": "", "source_has_tag": "weapon", "target_has_tag": "armor", "spatial_target_count": "min:1|max:3", "health_below_pct": "0.35", "health_above_pct": "0.5", "resource_at_least": "resource:stamina|amount:2", "status_stacks_at_least": "status_id:poison|stacks:3", "trigger_count_max": "6", "build_tag_count": "tag:weapon|min:2", "enemy_has_status": "burn", "overheal_positive": ""}
		for row in db.rows("condition_templates"):
			check(readable(formatter.condition(row.id, examples[row.id], language)), "all condition templates " + str(row.id) + " " + language)
		var effect_values = {"physical_damage": "amount:4", "true_damage": "amount:4", "gain_armor": "amount:3", "heal": "amount:5", "gain_stamina": "amount:2", "apply_status": "status_id:poison|stacks:2", "remove_status": "status_id:negative|stacks:3", "convert_status": "from:poison|to:regeneration|ratio:0.5", "modify_cooldown_pct": "value:-0.1|duration:8", "modify_damage_flat": "value:2", "modify_crit_chance": "value:0.1", "modify_status_power": "value:0.2", "advance_cooldown": "seconds:0.5", "gain_gold": "amount:2", "free_refresh": "count:1", "max_health": "amount:3"}
		for row in db.rows("effect_templates"):
			check(readable(formatter.effect({"effect_type": row.id, "effect_params": effect_values[row.id], "trigger_id": "combat_start"}, language)), "all16 effect formats " + str(row.id) + " " + language)
		var dictionary = formatter.dictionary(language)
		check(dictionary.size() >= 35, "full gameplay dictionary beyond status list " + language)
		for term in dictionary: check(readable(str(term.term)) and readable(str(term.definition)), "readable dictionary entry " + str(term.id) + " " + language)
		for id in ["armor", "cleanse", "occupied_cells", "valid_cells", "star", "lock", "interest", "craft", "chain", "fatigue"]:
			check(dictionary.any(func(entry): return entry.id == id), "dictionary includes required concept " + id + " " + language)
	check(formatter.affix("status_echo").contains("25%") and formatter.affix("status_echo").contains("8"), "status echo exposes exact ratio and combat limit")
	check(formatter.affix("accelerated_opening").contains("-10%") and formatter.affix("accelerated_opening").contains("8"), "opening speed exposes exact percent and duration")
	check(formatter.item("sharpening_stone").contains("武器") and formatter.item("sharpening_stone").contains("四向相邻"), "item condition uses shared tag and range terms")
	var report = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "source_sha256": FileAccess.get_file_as_string("res://PvE/Rules/content/RuleText.gd").sha256_text(), "content_sha256": db.content_sha256, "samples": samples}
	var file = FileAccess.open("res://rule_text_test_results.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	print("RULE_TEXT_TESTS ", JSON.stringify({"ok": report.ok, "checks": checks, "failures": failures})); quit(0 if failures.is_empty() else 1)
