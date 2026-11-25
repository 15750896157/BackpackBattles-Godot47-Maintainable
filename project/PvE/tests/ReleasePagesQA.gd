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
	var overlay = Expedition.panel.find_child("EnemyIntelOverlay",true,false)
	check(overlay != null,"enemy intel opens as a second-level overlay")
	if overlay != null:
		overlay._switch("build")
		await settle();await shot("01c-enemy-bag")
	var intel: Control = Expedition.panel.find_child("Ref_intel_paper",true,false)
	var grids: Array = Expedition.panel.find_children("*","Control",true,false).filter(func(node): return node.has_meta("pve_build_grid"))
	check(intel != null and grids.size() == 1 and intel.get_global_rect().encloses(grids[0].get_global_rect()),"enemy intel shows the actual backpack inside the new parchment")
	check(Expedition.flow.run.route_candidates == route_before,"opening enemy intel does not choose a route")
	if overlay != null:
		overlay.close()
	await settle()
	Expedition.flow.choose_route(0);await settle()
	var profile=Expedition.flow.profile_service.profile
	profile.seen_items.append_array(Expedition.db.release_catalog.items+Expedition.db.release_catalog.bags)
	profile.recipes.append_array(Expedition.db.release_catalog.recipes)
	profile.seen_enemies.append(str(opponent.get("enemy_id", "")))
	for category in ["items","bags","recipes","enemies","characters"]:
		Expedition.menus.library.show_page(category);await settle();await shot("02-book-"+category)
		check(Expedition.menus.library.PAGE_SIZE==4,"book uses four readable cards: "+category)
	Expedition.close_popup()
	await craft_from_codex()
	# A rest state fixture covers layout without fabricating a campaign result.
	Expedition.flow.screen_state="REST"
	Expedition.flow.run.current_node={"type":"rest","name_key":"ui.rest"}
	Expedition.menus.runs.event();await settle();await shot("03-camp")
	check(Expedition.panel.find_child("RestCampArt",true,false)!=null,"camp uses supplied full background")
	for button in Expedition.panel.find_children("*","BaseButton",true,false):
		if not button.is_visible_in_tree():continue
		var rect=button.get_global_rect()
		check(Rect2(-2,-2,1924,1084).encloses(rect),"camp target fits canvas: "+str(button.get_path()))
		if button is Button and button.text==Expedition.t("ui.confirm"):
			var contained=false
			for panel in Expedition.panel.find_children("RestChoicePanel_*","TextureRect",true,false):
				if panel.get_global_rect().encloses(rect):contained=true
			check(contained,"camp action fits its actual parchment panel")
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
