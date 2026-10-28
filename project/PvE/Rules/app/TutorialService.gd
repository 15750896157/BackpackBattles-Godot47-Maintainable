class_name TutorialService
extends RefCounted

var db

func _init(content = null):
	db = content

func active(profile: Dictionary, run: Dictionary, state: String, craftable: bool = false) -> Array:
	if run.get("difficulty_id", "") != "tutorial": return []
	var scope = {"SHOP_PREPARE": "shop", "ROUTE_SELECT": "route", "COMBAT_RUNNING": "combat", "COMBAT_RESULT": "result", "REWARD_SELECT": "reward", "RUN_RESULT": "run"}.get(state, "")
	var candidates: Array = []
	for step in db.rows("tutorial_steps"):
		if step.id in profile.get("tutorial_completed", []) or step.scene_scope != scope: continue
		var eligible = true
		match str(step.trigger):
			"first_shop_open": eligible = int(run.get("visit", 0)) == 1
			"item_held": eligible = "tutorial_01_pickup" in profile.tutorial_completed
			"item_rotated": eligible = "tutorial_02_rotate" in profile.tutorial_completed
			"valid_shop_item_placed": eligible = "tutorial_03_place" in profile.tutorial_completed
			"purchase_complete": eligible = "tutorial_05_buy" in profile.tutorial_completed
			"first_invalid_hover": eligible = false # The preview event completes this optional step directly.
			"second_shop_open": eligible = int(run.get("visit", 0)) >= 2
			"after_refresh": eligible = int(run.get("shop", {}).get("refresh_count", 0)) > 0
			"recipe_candidate_found": eligible = craftable
			"tutorial_boss_won": eligible = int(run.get("act", 0)) == 3 and float(run.get("health", 0)) > 0
		if eligible: candidates.append(step)
	candidates.sort_custom(func(a, b): return int(a.step_order) < int(b.step_order))
	return candidates

func can_start(profile: Dictionary, run: Dictionary, craftable: bool = false) -> Dictionary:
	for step in active(profile, run, "SHOP_PREPARE", craftable):
		if bool(step.blocking): return {"ok": false, "error": "tutorial_action_required", "step": step}
	return {"ok": true, "error": ""}
