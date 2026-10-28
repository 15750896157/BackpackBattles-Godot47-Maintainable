class_name CraftingService
extends RefCounted

var db
var placement
var spatial

func _init(content = null):
	db = content
	placement = PlacementService.new(content)
	spatial = SpatialQueryService.new(content)

func candidates(build: Dictionary, act: int) -> Array:
	var available: Array = []
	for recipe in db.rows("recipes"):
		if int(recipe.get("chapter_min", 1)) > act or int(recipe.get("tier", 1)) > 2:
			continue
		var materials: Array = []
		for ingredient in db.rows("recipe_ingredients"):
			if str(ingredient.recipe_id) == str(recipe.id):
				materials.append(ingredient)
		materials.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
		if materials.size() != 2:
			continue
		for first in build.get("items", []):
			if str(first.definition_id) != str(materials[0].item_id) or int(first.get("craft_tier", 0)) >= 2:
				continue
			for second in build.get("items", []):
				if str(second.definition_id) != str(materials[1].item_id) or str(first.uid) == str(second.uid) or int(second.get("craft_tier", 0)) >= 2:
					continue
				if not _space_matches(build, first, second, str(recipe.get("placement_rule", "adjacent_4"))):
					continue
				var uids = [str(first.uid), str(second.uid)]
				if str(materials[0].item_id) == str(materials[1].item_id) and uids[0] > uids[1]:
					continue
				available.append({"recipe_id": str(recipe.id), "result_item_id": str(recipe.result_item_id), "tier": int(recipe.get("tier", 1)), "priority": int(recipe.get("priority", 0)), "material_uids": uids, "consume": [bool(materials[0].get("consume", true)), bool(materials[1].get("consume", true))], "placement_rule": str(recipe.get("placement_rule", "adjacent_4")), "manual_confirm": true})
	available.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		if a.tier != b.tier:
			return a.tier > b.tier
		if a.recipe_id != b.recipe_id:
			return a.recipe_id < b.recipe_id
		return str(a.material_uids) < str(b.material_uids))
	# One material set receives the highest priority recipe; other combinations remain available.
	var result: Array = []
	var seen: Dictionary = {}
	for candidate in available:
		var key = candidate.material_uids.duplicate()
		key.sort()
		var encoded = "|".join(key)
		if not seen.has(encoded):
			seen[encoded] = true
			result.append(candidate)
	return result

func preview(run: Dictionary, recipe_id: String, options: Dictionary = {}) -> Dictionary:
	var candidate = run.duplicate(true)
	var selection: Dictionary = {}
	for recipe in candidates(candidate.build, int(candidate.get("act", 1))):
		if str(recipe.recipe_id) == recipe_id and (not options.has("material_uids") or recipe.material_uids == options.material_uids):
			selection = recipe
			break
	if selection.is_empty():
		return {"ok": false, "error": "craft_requirements_not_met", "message": "当前材料、章节或空间关系不满足此配方。"}
	var consumed: Array = []
	for index in range(selection.material_uids.size()):
		var found = placement.find(candidate.build, selection.material_uids[index])
		consumed.append(found.entry)
		if selection.consume[index]:
			var removed = placement.remove(candidate.build, selection.material_uids[index])
			if not removed.ok:
				return removed
	return _finish(candidate, selection, consumed, options)

func _finish(candidate: Dictionary, selection: Dictionary, consumed: Array, options: Dictionary) -> Dictionary:
	var recipe_id = str(selection.recipe_id)
	var entry = EconomyService.new(db).make_entry(candidate, str(selection.result_item_id))
	entry["crafted"] = true
	entry["craft_tier"] = int(selection.tier)
	entry["purchased_visit"] = -1
	entry["materials"] = consumed
	entry["used"] = consumed.any(func(material): return bool(material.get("used", false)))
	var result: Dictionary
	if options.has("x") and options.has("y"):
		result = placement.preview(candidate.build, entry, int(options.x), int(options.y), int(options.get("rotation", 0)))
		if not result.ok:
			return result
		candidate.build = result.build
	else:
		# Prefer the first material's former position, then search all legal orientations.
		result = placement.preview(candidate.build, entry, int(consumed[0].x), int(consumed[0].y), int(consumed[0].get("rotation", 0)))
		if result.ok:
			candidate.build = result.build
		else:
			result = placement.auto_place(candidate.build, entry)
	var pending = false
	if not result.ok:
		pending = true
		if not candidate.has("pending_rewards"):
			candidate["pending_rewards"] = []
		candidate.pending_rewards.append({"kind": "item", "definition_id": str(entry.definition_id), "source": "craft", "entry": entry.duplicate(true), "material_uids": selection.material_uids.duplicate()})
	if not candidate.has("recipes_discovered"):
		candidate["recipes_discovered"] = []
	if not candidate.recipes_discovered.has(recipe_id):
		candidate.recipes_discovered.append(recipe_id)
	return {"ok": true, "error": "", "run": candidate, "recipe": selection, "entry": entry, "pending": pending, "consumed": consumed}

func execute(run: Dictionary, recipe_id: String, options: Dictionary = {}) -> Dictionary:
	var result = preview(run, recipe_id, options)
	if result.ok:
		run.clear()
		run.merge(result.run, true)
	return result

func upgrade_candidates(build: Dictionary, act: int) -> Array:
	var results: Array = []
	var tier_one: Dictionary = {}
	for recipe in db.rows("recipes"):
		if int(recipe.get("tier", 1)) == 1:
			tier_one[str(recipe.result_item_id)] = true
	for recipe in db.rows("recipes"):
		if int(recipe.get("tier", 1)) != 2 or int(recipe.get("chapter_min", 1)) > act:
			continue
		for ingredient in db.rows("recipe_ingredients"):
			if str(ingredient.recipe_id) != str(recipe.id) or not tier_one.has(str(ingredient.item_id)):
				continue
			for entry in build.get("items", []) + build.get("storage", []):
				if str(entry.definition_id) == str(ingredient.item_id) and int(entry.get("craft_tier", 1)) < 2:
					results.append({"recipe_id": str(recipe.id), "source_uid": str(entry.uid), "result_item_id": str(recipe.result_item_id), "tier": 2})
	results.sort_custom(func(a, b): return a.recipe_id < b.recipe_id if a.recipe_id != b.recipe_id else a.source_uid < b.source_uid)
	return results

func upgrade(run: Dictionary, source_uid: String, recipe_id: String) -> Dictionary:
	var selection: Dictionary = {}
	for option in upgrade_candidates(run.get("build", {}), int(run.get("act", 1))):
		if option.source_uid == source_uid and option.recipe_id == recipe_id:
			selection = option
			break
	if selection.is_empty():
		return {"ok": false, "error": "upgrade_not_available", "message": "该物品没有已解锁的二阶配方升级。"}
	var candidate = run.duplicate(true)
	var source = placement.find(candidate.build, source_uid).entry
	var removed = placement.remove(candidate.build, source_uid)
	if not removed.ok:
		return removed
	selection["material_uids"] = [source_uid]
	var result = _finish(candidate, selection, [source], {})
	if result.ok:
		run.clear()
		run.merge(result.run, true)
	return result

func _space_matches(build: Dictionary, first: Dictionary, second: Dictionary, rule: String) -> bool:
	match rule:
		"adjacent_4", "same_bag":
			return spatial.targets(build, str(first.uid), rule).has(str(second.uid))
		"star_cell":
			for material in [first, second]:
				for special in spatial.special_cells(build, str(material.uid)):
					if special.type == "star_cell":
						return true
	return false
