extends RefCounted
## Adapts the existing journey services to the editable route screen.

const SCREEN_PATH = "res://PvE/UI/RouteScreen.tscn"
const SCREEN = preload("res://PvE/UI/RouteScreen.gd")
const LEGACY = preload("res://PvE/UI/RouteLayout.gd")
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")
const ENEMY_ART = preload("res://PvE/Art/NewArtCatalog.gd")
const ShopVM = preload("res://Code/Runtime/ViewModel/ShopVM.gd")

static func mount(page, model: ShopVM, root: Control, ticket: int) -> bool:
	var owner = page.owner
	model.refresh()
	var snapshot := model.snapshot()
	var candidates: Array = snapshot.route_candidates
	if not _current(owner, root, ticket) or candidates.is_empty() or candidates.size() > 3:
		return false
	var paths := REF.paths(LEGACY.KEYS)
	paths.append(SCREEN_PATH)
	var portraits: Array[String] = []
	for candidate in candidates:
		portraits.append(page.portrait_path(candidate))
	paths.append_array(portraits)
	var loaded: bool = await AssetStream.prepare(paths, "popup")
	if not loaded or not _current(owner, root, ticket):
		return false
	var screen = await AssetStream.instantiate_path(SCREEN_PATH, "popup")
	if not screen is SCREEN:
		if is_instance_valid(screen): screen.free()
		return false
	model.refresh()
	var prepared := model.snapshot()
	if not _current(owner, root, ticket) or prepared.route_candidates != candidates or prepared.mode != snapshot.mode or prepared.route_pending != snapshot.route_pending:
		screen.free()
		return false
	var art: Dictionary = {}
	for key in LEGACY.KEYS:
		art[key] = REF.texture(key)
		if art[key] == null:
			screen.free()
			return false
	var descriptions: Array[Dictionary] = []
	for index in candidates.size():
		var texture: Texture2D = AssetStream.resources.get(portraits[index])
		if texture == null:
			screen.free()
			return false
		descriptions.append(_describe_card(page, candidates[index], texture))
	if not screen.configure(_describe_header(page, prepared), descriptions, art, owner.ui_font):
		screen.free()
		return false
	screen.choice_requested.connect(func(index: int):
		if _current(owner, root, ticket):
			model.refresh()
			if _current(owner, root, ticket) and model.snapshot().route_candidates == candidates:
				model.choose_route(index))
	screen.intel_requested.connect(func(index: int):
		if _current(owner, root, ticket):
			page.section = "abilities"
			page.show_page(candidates[index]))
	screen.back_requested.connect(func():
		if _current(owner, root, ticket):
			if snapshot.route_pending:
				owner.close_popup()
			else:
				owner.return_to_title())
	screen.settings_requested.connect(func():
		if _current(owner, root, ticket):
			owner.show_settings())
	screen.codex_requested.connect(func():
		if _current(owner, root, ticket):
			owner.show_codex())
	root.add_child(screen)
	REF.fade_in(screen)
	return true

static func _current(owner, root: Control, ticket: int) -> bool:
	return is_instance_valid(owner) and is_instance_valid(root) and root.is_inside_tree() and owner.popup_epoch == ticket

static func _describe_header(page, snapshot: Dictionary) -> Dictionary:
	return {
		"route_pending": snapshot.route_pending,
		"gold": str(snapshot.gold),
		"health": "%d/%d" % [snapshot.health, snapshot.max_health],
		"act": page.ui.words("第 %d 章 · 第 %d 站", "Act %d · Node %d") % [snapshot.act, snapshot.step],
		"hint": page.ui.words("可先整理商店 · 开战前须选定路线", "Shop first · Choose a route before battle"),
	}

static func _describe_card(page, node: Dictionary, portrait: Texture2D) -> Dictionary:
	var owner = page.owner
	var ui = page.ui
	var type: String = node.type
	var enemy = owner.db.get_row("enemy_builds", str(node.get("enemy_id", "")))
	var tags = owner.db.list_values(enemy.get("threat_tags", ""))
	var names: Array[String] = []
	for tag in tags.slice(0, 2):
		names.append(owner.detail_views.tag_name(tag))
	var rewards: Array = LEGACY.reward_intentions(owner, node)
	var elite := type == "elite_combat" or type == "boss"
	var row := {
		"elite": elite,
		"tab": "route_tab_elite" if elite else "route_tab_danger" if type == "danger_combat" else "route_tab",
		"name": owner.t(node.name_key),
		"subtitle": owner.enemy_name(node) if type.ends_with("combat") or type == "boss" else ui.words("补给与抉择", "Supplies & choices"),
		"portrait": portrait,
		"tint": ENEMY_ART.enemy_variant(node).tint,
		"threat": ui.words("主要威胁 · ", "Threat · ") + " / ".join(names) if not names.is_empty() else ui.words("补给与休整", "Supplies & recovery"),
		"intel": ui.words("查看完整敌情", "Inspect enemy details"),
		"possible_rewards": ui.words("可能奖励", "Possible rewards"),
		"rewards": rewards,
		"prepare": ui.words("准备出发", "Prepare"),
	}
	for index in rewards.size():
		row["reward%d" % index] = rewards[index]
	return row
