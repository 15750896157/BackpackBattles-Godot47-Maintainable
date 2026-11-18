extends "res://PvE/tests/RestartResidencyQA.gd"
## Isolated presentation fixtures; gameplay transactions are tested separately.
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle()
	if "--english-large" in OS.get_cmdline_user_args():
		Expedition.preferences.values.language="en";Settings.setVal(Settings.Setting.language,"en")
		Expedition.preferences.values.ui_scale=1.4;Expedition.ui_theme.default_font_size=34
	for row in Expedition.db.rows("tutorial_steps"):Expedition.flow.profile_service.profile.tutorial_completed.append(row.id)
	Expedition.create_run("archer","archer_precision","tutorial",1431,true)
	await settle();await shot("01-new-route")
	check(Expedition.panel.find_child("RouteGo_0",true,false)!=null,"new journey provides direct prepare targets")
	for portrait in Expedition.panel.find_children("RoutePortrait_*","TextureRect",true,false):
		check(portrait.size==Vector2(350,314),"route portrait stays inside authored bounds: "+portrait.name)
	var route_before: Array = Expedition.flow.run.route_candidates.duplicate(true)
	var opponent: Dictionary = route_before.filter(func(node): return str(node.type).ends_with("combat") or node.type == "boss")[0]
	Expedition.menus.journey.show_page(opponent)
	await settle();await shot("01b-enemy-intel")
	var intel: Control = Expedition.panel.find_child("Ref_intel_paper",true,false)
	var grids: Array = Expedition.panel.find_children("*","Control",true,false).filter(func(node): return node.has_meta("pve_build_grid"))
	check(intel != null and grids.size() == 1 and intel.get_global_rect().encloses(grids[0].get_global_rect()),"enemy intel shows the actual backpack inside the new parchment")
	check(Expedition.flow.run.route_candidates == route_before,"opening enemy intel does not choose a route")
	Expedition.view_return()
	await settle()
	Expedition.flow.choose_route(0);await settle()
	var profile=Expedition.flow.profile_service.profile
	profile.seen_items.append_array(Expedition.db.release_catalog.items+Expedition.db.release_catalog.bags)
	profile.recipes.append_array(Expedition.db.release_catalog.recipes)
	for enemy in Expedition.db.rows("enemy_builds"):
		profile.seen_enemies.append(str(enemy.id))
	for category in ["items","bags","recipes","enemies","characters"]:
		Expedition.menus.library.show_page(category);await settle()
		if category=="characters":
			var archer: BaseButton = Expedition.panel.find_child("BookEntry_archer",true,false)
			if archer != null: await click(archer);await settle()
		await shot("02-book-"+category)
		check(Expedition.menus.library.PAGE_SIZE==4,"book uses four readable cards: "+category)
	Expedition.close_popup()
	await craft_from_codex()
	# Choose a rest card through the same viewport path as a real route.
	var flow: GameFlow = Expedition.flow
	flow.run["shop_first_routes"] = true
	flow.run["route_pending"] = true
	flow.run.route_candidates = [{"type":"rest", "name_key":"ui.rest", "enemy_id":"",
		"event_id":"", "boss_id":"", "affix_id":"", "reward_table_id":"reward_none",
		"act":flow.run.act, "step":flow.run.step}]
	Expedition.show_routes()
	await settle()
	await click(Expedition.panel.find_child("RouteGo_0", true, false))
	await settle()
	check(flow.screen_state == "REST", "rest card enters the actual camp")
	await shot("03-camp")
	check(Expedition.panel.find_child("RestCampArt",true,false)!=null,"camp uses supplied full background")
	check(Expedition.panel.find_child("JourneyCodex",true,false)==null,"camp has no stray catalogue shortcut")
	for button in Expedition.panel.find_children("*","BaseButton",true,false):
		if not button.is_visible_in_tree():continue
		var rect=button.get_global_rect()
		check(Rect2(-2,-2,1924,1084).encloses(rect),"camp target fits canvas: "+str(button.get_path()))
		if button is Button and button.text==Expedition.t("ui.confirm"):
			var contained=false
			for panel in Expedition.panel.find_children("RestChoicePanel_*","TextureRect",true,false):
				if panel.get_global_rect().encloses(rect):contained=true
			check(contained,"camp action fits its actual parchment panel")
	await check_shop_after_choice()
	await check_distinct_guide_pages()
	await check_run_summary_return()
	await Expedition.return_to_title();await settle()
	var file=FileAccess.open(output.path_join("release-pages-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)

func craft_from_codex() -> void:
	var flow: GameFlow = Expedition.flow
	var recipe_id := "recipe_supply_vine_bow"
	var bow := flow._entry("supply_wooden_bow", "qa-bow")
	var ring := flow._entry("supply_vine_ring", "qa-ring")
	for cell: Vector2i in flow.placement.local_cells(bow):
		ring.x = maxi(int(ring.x), cell.x + 1)
	flow.run.build = {"width": 9, "height": 7, "bags": [flow._entry("bag_release_transport", "qa-bag")],
		"items": [bow, ring], "storage": [], "storage_capacity": 2}
	var candidates := CraftingManager.pve_candidates().filter(func(row): return row.recipe_id == recipe_id)
	check(flow.placement.validate(flow.run.build).ok and not candidates.is_empty(), "real codex recipe has valid adjacent ingredients")
	if candidates.is_empty():
		return
	Expedition.show_craft_confirmation(candidates[0])
	await settle()
	var confirm: BaseButton = Expedition.panel.find_child("BookConfirmCraft", true, false)
	check(confirm != null and not confirm.disabled, "known recipe uses the native preview to enable confirmation")
	if confirm != null and not confirm.disabled:
		await click(confirm)
		await settle()
		check(flow.run.build.items.size() == 1 and flow.run.build.items[0].definition_id == "supply_vine_bow",
			"codex confirms the original recipe transaction with the exact displayed ingredients")
	Expedition.close_popup()

func check_shop_after_choice() -> void:
	var flow: GameFlow = Expedition.flow
	# Exercise the existing rest transaction first, then a separate event in the
	# same isolated fixture. Each opens a genuine stock and real next route.
	await continue_from_choice("camp")
	if flow.screen_state != "SHOP_PREPARE": return
	flow.run.completed_nodes.clear()
	var event: Dictionary = Expedition.db.rows("events")[0]
	var candidate := {"type":"event", "enemy_id":"", "event_id":event.id,
		"boss_id":"", "affix_id":"", "reward_table_id":"reward_none", "act":flow.run.act, "step":flow.run.step,
		"name_key":event.title_key}
	flow.run.route_candidates = [candidate]
	Expedition.show_routes()
	await settle()
	await click(Expedition.panel.find_child("RouteGo_0", true, false))
	await settle()
	check(flow.screen_state == "EVENT", "event fixture enters the real event page")
	if flow.screen_state == "EVENT": await continue_from_choice("event")

func continue_from_choice(kind: String) -> void:
	var flow: GameFlow = Expedition.flow
	var button: BaseButton
	for target in Expedition.panel.find_children("*", "Button", true, false):
		if target.text == Expedition.t("ui.confirm") and not target.disabled:
			if kind == "event":
				var title: Label = target.get_parent().get_child(0)
				if title.text != Expedition.t("event_choice.event_abandoned_cart_strip.text"): continue
			button = target
			break
	if button == null:
		check(false, kind + " has an actionable option")
		return
	await click(button)
	await settle()
	check(flow.screen_state == "SHOP_PREPARE" and Game.state == Game.State.Shop, kind + " returns to the actual shop")
	var dismiss: BaseButton = Expedition.panel.find_child("RouteCancel", true, false)
	check(dismiss != null, kind + " opens the genuine next route")
	if dismiss == null: return
	await click(dismiss)
	await settle()
	check(Expedition.art.routed_shop.is_visible_in_tree() and Expedition.art.ui.get_node_or_null("ArtStartBattle") != null
		and not Expedition.panel.visible and not InputBlocker.isActive(), kind + " leaves the shop HUD and controls available")
	await shot("shop-after-" + kind)

func check_distinct_guide_pages() -> void:
	var flow: GameFlow = Expedition.flow
	check(Expedition.create_run("alchemist","alchemist_toxin","tutorial",1431,true).ok,
		"tutorial fixture starts with the actual alchemist profession")
	await settle()
	var next_combat: int = flow.run.route_candidates.find_custom(func(node):
		return str(node.type).ends_with("combat") or node.type == "boss")
	check(next_combat >= 0 and flow.choose_route(next_combat).ok, "guide fixture chooses a real combat route")
	await settle()
	flow.profile_service.profile.tutorial_completed.erase("tutorial_07_enemy")
	await click(Expedition.art.ui.get_node_or_null("ArtStartBattle"))
	await settle()
	var pictures: BaseButton = Expedition.panel.find_child("GuideShowIllustrations", true, false)
	check(Expedition.current_page == "UI_GUIDE" and pictures != null, "pending alchemist tutorial opens the exercise")
	if pictures == null: return
	var exercise_text: String = Expedition.popup_content.get_child(0).text
	await click(pictures)
	await settle()
	var back: BaseButton = Expedition.panel.find_child("GuideShowExercise", true, false)
	check(back != null and Expedition.panel.find_child("GuideShowIllustrations", true, false) == null,
		"the illustrations page has distinct controls and no exercise navigation duplicate")
	if back == null: return
	await shot("guide-illustrations")
	await click(back)
	await settle()
	check(Expedition.popup_content.get_child(0).text == exercise_text,
		"returning from illustrations restores the active exercise without marking it complete")
	Expedition.close_popup()

func check_run_summary_return() -> void:
	var flow: GameFlow = Expedition.flow
	# The actual final-boss transaction is covered in PostBattleQA; exercise
	# the view on its terminal state without replaying a campaign.
	flow.run.act = 3
	flow.run.completed_nodes.append({"type":"boss"})
	flow._transition("RUN_RESULT")
	Expedition.show_summary()
	await settle()
	var back: BaseButton = Expedition.panel.find_child("RunSummaryReturnHome", true, false)
	check(back != null, "finished expedition has a direct home action")
	if back == null: return
	await click(back)
	check(await wait_until(func(): return Game.state == Game.State.Title and idle()),
		"finished expedition returns to main menu without opening character selection")
