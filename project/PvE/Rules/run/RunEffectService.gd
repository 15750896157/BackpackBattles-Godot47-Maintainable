class_name RunEffectService
extends RefCounted

var db
var placement
var crafting
var rewards

func _init(content = null):
	db = content
	placement = PlacementService.new(content)
	crafting = CraftingService.new(content)
	rewards = RewardService.new(content)

func eligible_items(run: Dictionary, selector: String) -> Array:
	var entries: Array = []
	for entry in run.build.items + run.build.storage:
		var row = db.get_row("items", entry.definition_id)
		if row.is_empty(): continue
		if selector.ends_with("_tag_utility") and "utility" not in db.list_values(row.tags): continue
		if selector.ends_with("_rarity_common") and row.rarity != "common": continue
		entries.append(entry)
	return entries

func requirements(run: Dictionary, expression: String) -> Dictionary:
	if expression in ["", "none", "always"]: return {"ok": true, "error": ""}
	for part in expression.split("|"):
		var bits = part.split(":")
		var valid = true
		match bits[0]:
			"gold_min": valid = int(run.gold) >= int(bits[1])
			"health_above_pct": valid = float(run.health) / float(run.max_health) > float(bits[1])
			"storage_below": valid = int(run.build.storage_capacity) < int(bits[1])
			"item_count_min": valid = (run.build.items.size() + run.build.storage.size()) >= int(bits[1])
			"tag_item_min", "rarity_item_min":
				var count = 0
				for entry in run.build.items + run.build.storage:
					var item = db.get_row("items", entry.definition_id)
					if item.is_empty(): continue
					if (bits[0] == "tag_item_min" and bits[1] in db.list_values(item.tags)) or (bits[0] == "rarity_item_min" and item.rarity == bits[1]): count += 1
				valid = count >= int(bits[2])
			"craftable_tier_1":
				valid = false
				for candidate in crafting.candidates(run.build, int(run.act)):
					var recipe = db.get_row("recipes", str(candidate.get("recipe_id", candidate.get("id", ""))))
					if int(recipe.get("tier", 0)) == 1: valid = true
			_:
				valid = false
		if not valid: return {"ok": false, "error": "requirement_not_met", "requirement": part}
	return {"ok": true, "error": ""}

func apply(run: Dictionary, effects: Array, options: Dictionary = {}) -> Dictionary:
	var draft = run.duplicate(true)
	var messages: Array = []
	for effect in effects:
		var result = _one(draft, str(effect.get("effect_type", effect.get("type", ""))), db.parse_params(effect.get("params", "")), options)
		if not result.ok: return result
		messages.append(result)
	run.clear()
	run.merge(draft, true)
	return {"ok": true, "error": "", "effects": messages}

func _one(run: Dictionary, type: String, params: Dictionary, options: Dictionary) -> Dictionary:
	var amount = float(params.get("amount", 0))
	match type:
		"gold":
			if int(run.gold) + int(amount) < 0: return {"ok": false, "error": "not_enough_gold"}
			run.gold = int(run.gold) + int(amount)
		"heal_flat": run.health = minf(float(run.max_health), float(run.health) + amount)
		"heal_pct": run.health = minf(float(run.max_health), float(run.health) + float(run.max_health) * amount)
		"damage_pct": run.health = maxf(float(params.get("min_health", 1)), float(run.health) - float(run.max_health) * amount)
		"item_pool", "bag_pool", "specific_item":
			var ids: Array = []
			if type == "specific_item": ids = [str(params.get("item_id", ""))]
			else: ids = rewards.content_pool(run, type, params)
			if ids.is_empty(): return {"ok": false, "error": "reward_pool_empty"}
			var rng = DeterministicRNG.new(int(run.rng.reward))
			for _index in int(params.get("count", 1)):
				var id = str(rng.choose(ids))
				run.pending_rewards.append({"kind": "bag" if type == "bag_pool" else "item", "definition_id": id, "source": "event", "type": "pending_item"})
			run.rng.reward = rng.state
		"remove_item":
			var uid = str(options.get("item_uid", ""))
			var permitted = eligible_items(run, str(params.get("selector", "player_choice")))
			var found = false
			for entry in permitted:
				if entry.uid == uid: found = true
			if not found: return {"ok": false, "error": "choose_eligible_item"}
			var result = placement.remove(run.build, uid, false)
			if not result.ok: return result
		"upgrade_item", "recipe_upgrade":
			var candidates = crafting.upgrade_candidates(run.build, int(run.act))
			if candidates.is_empty():
				run["shop_discount"] = maxf(float(run.get("shop_discount", 0)), float(params.get("fallback_discount", 0.20)))
				run["shop_discount_remaining"] = int(params.get("duration_shops", 1))
			else:
				var recipe_id = str(options.get("recipe_id", ""))
				var uid = str(options.get("item_uid", ""))
				var result = crafting.upgrade(run, uid, recipe_id)
				if not result.ok: return result
		"execute_recipe":
			var recipe_id = str(options.get("recipe_id", ""))
			var recipe = db.get_row("recipes", recipe_id)
			if recipe.is_empty() or int(recipe.tier) > int(params.get("tier_max", 2)):
				return {"ok": false, "error": "choose_eligible_recipe"}
			var result = crafting.execute(run, recipe_id, options)
			if not result.ok: return result
		"free_refresh":
			run["free_refreshes"] = int(run.get("free_refreshes", 0)) + int(params.get("amount", params.get("count", 1)))
			run["free_refresh_expiry"] = total_nodes(run) + int(params.get("duration_nodes", 2))
		"shop_discount":
			run["shop_discount"] = maxf(float(run.get("shop_discount", 0)), amount)
			run["shop_discount_remaining"] = int(params.get("duration_shops", 1))
		"sell_ratio_bonus":
			run["sell_ratio_bonus"] = amount
			run["sell_bonus_expiry"] = total_nodes(run) + int(params.get("duration_nodes", 1))
		"interest_cap_delta":
			run["interest_cap_delta"] = int(amount)
			run["interest_bonus_remaining"] = int(params.get("duration_battles", 3))
		"storage_slot":
			var old = int(run.build.storage_capacity)
			run.build.storage_capacity = mini(int(db.value("storage_cap", 4)), old + int(amount))
			if int(run.build.storage_capacity) == old: run.gold = int(run.gold) + int(params.get("fallback_gold", 5))
		"recipe_discovery":
			var unseen: Array = []
			for recipe in db.rows("recipes"):
				if int(recipe.tier) == int(params.get("tier", 1)) and recipe.id not in run.get("recipes_discovered", []): unseen.append(recipe.id)
			if not run.has("recipes_discovered"): run["recipes_discovered"] = []
			var rng = DeterministicRNG.new(int(run.rng.reward))
			for _index in int(params.get("count", 1)):
				if unseen.is_empty(): break
				var id = rng.choose(unseen)
				run.recipes_discovered.append(id)
				unseen.erase(id)
			run.rng.reward = rng.state
		"cleanse_run_debuff":
			var count = int(params.get("count", 1))
			var kept: Array = []
			for effect in run.get("run_effects", []):
				if count > 0 and bool(effect.get("negative", false)): count -= 1
				else: kept.append(effect)
			run["run_effects"] = kept
		_:
			return {"ok": false, "error": "unknown_run_effect_" + type}
	return {"ok": true, "error": "", "type": type, "params": params}

func total_nodes(run: Dictionary) -> int:
	return run.completed_nodes.size()

func expire_node(run: Dictionary):
	if total_nodes(run) >= int(run.get("free_refresh_expiry", 99999)): run["free_refreshes"] = 0
	if total_nodes(run) >= int(run.get("sell_bonus_expiry", 99999)): run["sell_ratio_bonus"] = 0.0
