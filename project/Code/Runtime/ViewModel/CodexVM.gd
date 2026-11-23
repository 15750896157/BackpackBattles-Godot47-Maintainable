extends ViewModel
## Catalogue snapshots use the same discovery, release and crafting services as the run.
## 临时调试开关：图鉴全解锁（看完改回 false）。
const DEBUG_UNLOCK_ALL := false
const PAGE_SIZE := 4
const RECORD_PAGE_SIZE := 6
var _flow: GameFlow
var _rules
var _translate: Callable
var _words: Callable
var _describe: Callable
var _tag: Callable
var _candidates: Callable

func _init(flow: GameFlow, rules, translate: Callable, words: Callable,
		describe: Callable, tag: Callable, candidates: Callable) -> void:
	_flow = flow
	_rules = rules
	_translate = translate
	_words = words
	_describe = describe
	_tag = tag
	_candidates = candidates

func snapshot() -> Dictionary:
	var active := not _flow.run.is_empty() and _flow.screen_state != "MAIN_MENU"
	var legacy: bool = active and not _flow.db.release_run(_flow.run)
	return {
		"active": active,
		"legacy": legacy,
		"can_craft": active and _flow.screen_state == "SHOP_PREPARE",
		"pools": ["all", "public", "armorer", "archer", "alchemist"],
		"tags": ["all"] + _flow.db.rows("tags").map(func(row): return row.id),
	}

func catalogue(category: String, filters: Dictionary, requested_page: int,
		selection: String, requested_recipe: String) -> Dictionary:
	var context := snapshot()
	var profile: Dictionary = _flow.profile_service.profile
	var source: Array = _flow.db.rows("enemy_builds") + _flow.db.rows("bosses") if category == "enemies" else (_flow.db.rows("items") if category == "items" else _flow.db.catalogue_rows(category, context.legacy))
	# 调试：绕过 release_catalog 发布清单过滤，图鉴显示全表物品。
	if DEBUG_UNLOCK_ALL and category in ["items", "bags", "recipes"]:
		source = _flow.db.rows(category)
	if category == "characters":
		source = _flow.db.rows("characters")
	var available := {}
	if context.can_craft and category == "recipes":
		for candidate: Dictionary in _candidates.call():
			available[candidate.recipe_id] = candidate
	var matches: Array[Dictionary] = []
	var query := str(filters.query).to_lower()
	var pool: String = filters.pool if filters.pool in context.pools else "all"
	for data: Dictionary in source:
		var id := str(data.get("result_item_id", data.id)) if category == "recipes" else str(data.id)
		var definition: Dictionary = data if category in ["enemies","characters"] else _flow.placement.definition(id)
		var title: String = _translate.call(definition.get("name_key", id))
		var known: bool = DEBUG_UNLOCK_ALL or category == "characters" or (data.id in profile.recipes if category == "recipes" else data.id in profile.seen_enemies if category == "enemies" else data.id in profile.seen_items)
		if filters.seen and not known:
			continue
		if filters.available and not available.has(data.id):
			continue
		if pool != "all" and str(definition.get("owner_pool", "public")) != pool:
			continue
		if filters.rarity != "all" and str(definition.get("rarity", "common")) != filters.rarity:
			continue
		if filters.tag != "all" and filters.tag not in _flow.db.list_values(definition.get("tags", "")):
			continue
		if not query.is_empty() and (not known or not (title + " " + str(definition.get("tags", ""))).to_lower().contains(query)):
			continue
		matches.append({
			"data": data, "definition": definition, "id": id, "known": known,
			"title": title if known or (filters.available and available.has(data.id)) else _words.call("未发现", "Unknown"),
			"candidate": available.get(data.id, {}),
		})
	var count := maxi(1, ceili(matches.size() / float(PAGE_SIZE)))
	var page := clampi(requested_page, 0, count - 1)
	if category == "recipes" and not requested_recipe.is_empty():
		for index in matches.size():
			if matches[index].data.id == requested_recipe:
				page = index / PAGE_SIZE
				selection = matches[index].id
				break
	var visible := matches.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)
	var selected := {}
	for entry in visible:
		if entry.id == selection:
			selected = entry
	if selected.is_empty() and not visible.is_empty():
		selected = visible[0]
	return {"matches": matches, "visible": visible, "selected": selected, "page": page, "count": count, "pool": pool}

func subtitle(category: String, entry: Dictionary) -> String:
	if not entry.known:
		return _words.call("探索远征以记录", "Discover on an expedition")
	if category == "enemies":
		return _words.call("敌方构筑与能力", "Enemy build & abilities")
	if category == "characters":
		return _words.call("可选英雄", "Playable hero") if entry.id in _flow.db.release_catalog.characters else _words.call("旧版角色", "Legacy hero")
	return _translate.call("rarity." + str(entry.definition.get("rarity", "common")) + ".name") + "  ·  " + str(_cells(entry.id, 0).size()) + _words.call(" 格", " cells")

func detail(category: String, entry: Dictionary, rotation: int) -> Dictionary:
	var definition: Dictionary = entry.definition
	var cells := _cells(entry.id, rotation)
	var info: String = _words.call("占用 %d 格", "Occupies %d cells") % cells.size()
	if entry.known:
		info = _translate.call("rarity." + str(definition.get("rarity", "common")) + ".name") + " · " + info + " · " + _words.call("基础价格：", "Base price: ") + str(definition.get("base_price", 0))
	var ingredients: Array[String] = []
	if category == "recipes":
		var recipe_id := str(entry.candidate.get("recipe_id", entry.data.id))
		for row in _flow.db.rows("recipe_ingredients"):
			if row.recipe_id == recipe_id:
				ingredients.append(str(row.item_id))
	var description: String
	if entry.known:
		description = _describe.call(entry.id)
	else:
		var terms: Array[String] = []
		for id in ingredients:
			var tags: Array = _flow.db.list_values(_flow.placement.definition(id).get("tags", ""))
			terms.append(_tag.call(str(tags[0])) if not tags.is_empty() else "?")
		description = " + ".join(terms) + " → ?" if not terms.is_empty() else _words.call("发现后解锁完整记录", "Discover to reveal the full record")
	return {
		"info": info, "description": description, "ingredients": ingredients,
		"cells": cells, "base_cells": _cells(entry.id, 0),
		"effects": _effect_cells(entry.id, rotation, cells),
	}

func _cells(id: String, rotation: int) -> Array:
	return _flow.placement.local_cells({"definition_id": id, "rotation": rotation})

func _effect_cells(id: String, rotation: int, cells: Array) -> Dictionary:
	var source := {"definition_id": id, "rotation": rotation, "x": 3, "y": 3, "uid": "codex-preview"}
	var preview := {"width": 9, "height": 7, "items": [source], "bags": [], "storage": []}
	var effects := {}
	for effect in _flow.db.rows("item_effects"):
		if effect.item_id != id:
			continue
		var result = _flow.spatial.query(preview, str(source.uid), str(effect.spatial_template_id))
		for cell in result.cells:
			var target := Vector2i(cell) - Vector2i(3, 3)
			if not cells.has(target):
				effects[target] = true
	return effects

func rules_page(requested_page: int) -> Dictionary:
	var locale := TranslationServer.get_locale()
	var source: Array = _rules.dictionary(locale)
	var page := clampi(requested_page, 0, maxi(0, source.size() - 1))
	var profile: Dictionary = _flow.profile_service.profile
	var affixes: Array[String] = []
	for data in _flow.db.rows("encounter_affixes"):
		if data.id in profile.seen_affixes:
			affixes.append(_rules.affix(data, locale))
	return {"page": page, "count": maxi(1, source.size()), "rule": source[page] if not source.is_empty() else {}, "affixes": affixes}

func records_page(mode: int, requested_page: int) -> Dictionary:
	var profile: Dictionary = _flow.profile_service.profile
	var source: Array = _flow.db.rows("achievements") if mode == 0 else profile.run_history
	var count := maxi(1, ceili(source.size() / float(RECORD_PAGE_SIZE)))
	var page := clampi(requested_page, 0, count - 1)
	var rows: Array[String] = []
	for data in source.slice(page * RECORD_PAGE_SIZE, (page + 1) * RECORD_PAGE_SIZE):
		if mode == 0:
			rows.append(("✓ " if data.id in profile.achievements else "○ ") + _translate.call(data.name_key))
		else:
			rows.append(_translate.call(_flow.db.get_row("characters", data.character_id).name_key) + " · " + _translate.call("ui.run_cleared" if data.clear else "ui.run_failed"))
	var stars: Array[String] = []
	for character in _flow.db.rows("characters"):
		stars.append(_translate.call(character.name_key) + "  " + str(profile.character_clears.get(character.id, []).size()) + " ★")
	return {"page": page, "count": count, "rows": rows, "stars": stars}

func craft(candidate: Dictionary) -> Dictionary:
	if not snapshot().can_craft:
		return {"ok": false, "error": "wrong_state"}
	return _flow.craft(candidate.recipe_id, {"material_uids": candidate.material_uids})
