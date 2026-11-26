extends Node
const REF=preload("res://PvE/UI/ReferenceCanvas.gd")
var output=""
var checks:Array=[]
var failures:Array=[]
var geometry:Dictionary={}
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")
func check(value,message):
	checks.append({"ok":bool(value),"message":message})
	if not value:failures.append(message);print("REFERENCE_FAIL ",message)
func settle():
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	for frame in 12:await get_tree().process_frame
func shot(name):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))
func rect_data(node:Control)->Array:
	var rect=node.get_global_rect()
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func caption_of(button:Control,node_name:String="Caption")->Label:
	return button.get_node_or_null(node_name) as Label
## One shared standard for every button caption in the game: centred on both
## axes, inside its button, and sized from the shared ladder.
func check_caption(label:Label,button:Control,name:String,centred:bool=true):
	if label==null or not label.is_visible_in_tree():return
	check(label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,name+": caption centred horizontally")
	check(label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,name+": caption centred vertically")
	var br=button.get_global_rect();var lr=label.get_global_rect()
	check(br.grow(4).encloses(lr),name+": caption stays inside its button")
	if centred:
		check(absf(lr.get_center().x-br.get_center().x)<=2.5,name+": caption centred on X")
		check(absf(lr.get_center().y-br.get_center().y)<=4.0,name+": caption centred on Y")
	var size=label.get_theme_font_size("font_size")
	check(size>=16 and REF.font_step(size)==size,name+": caption size "+str(size)+" is on the shared ladder")
func check_caption_block(labels:Array,button:Control,name:String):
	var block=Rect2();var first=true
	for label in labels:
		if label==null or not label.is_visible_in_tree():continue
		check(label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,name+": caption line centred horizontally")
		var lr=label.get_global_rect()
		block=lr if first else block.merge(lr);first=false
	if first:return
	var br=button.get_global_rect()
	check(br.grow(2).encloses(block),name+": caption block stays inside its button")
	check(absf(block.get_center().x-br.get_center().x)<=2.5,name+": caption block centred on X")
	check(absf(block.get_center().y-br.get_center().y)<=3.0,name+": caption block centred on Y")
func capture_geometry(name:String,root:Node):
	var values={}
	for node in root.find_children("*","Control",true,false):
		if node.is_visible_in_tree() and (node is TextureRect or node is BaseButton):values[str(node.get_path())]=rect_data(node)
	geometry[name]=values
func click(control:Control):
	check(control!=null,"click target exists")
	if control==null:return
	var point=control.get_global_rect().get_center()
	print("CLICK ",control.name," ",point," panel ",Expedition.panel.position," ",Expedition.panel.visible)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;get_viewport().push_input(motion,true)
	print("HOVER ",get_viewport().gui_get_hovered_control())
	# Deliver the click as one viewport action before another pointer event can arrive.
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		get_viewport().push_input(event,true)
	await get_tree().process_frame
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	await settle();await shot("01-title")
	var hud_id = Expedition.hud_layer.get_instance_id()
	var dialog_id = Expedition.overlay.get_instance_id()
	check(Expedition.hud_layer.scene_file_path == "res://PvE/UI/HudLayer.tscn" and Expedition.overlay.scene_file_path == "res://PvE/UI/DialogLayer.tscn", "real editable HUD and dialog shell mounted")
	check(Expedition.art.layer.layer < Expedition.hud_layer.layer and Expedition.hud_layer.layer < Expedition.overlay.layer and Expedition.overlay.layer < Expedition.art.curtain.layer, "HUD, dialog and cloud preserve their draw order")
	var cloud_ticket=await Expedition.art.curtain.cover("qa_progress_overlay")
	check(Expedition.loading_screen.visible,"shared progress is visible during cloud cover")
	await shot("00-progress-over-cloud")
	await Expedition.art.curtain.reveal(cloud_ticket);await settle()
	capture_geometry("title",Expedition.art.ui)
	check(Expedition.art.ui.has_node("TitleExit"),"new title exit exists")
	for name in ["TitleStart","TitleExit","TitleNewRun"]:
		check_caption(caption_of(Expedition.art.ui.get_node(name)),Expedition.art.ui.get_node(name),"title "+name)
	await click(Expedition.art.ui.get_node("TitleSettings"));await settle();await shot("02-settings")
	capture_geometry("settings",Expedition.panel)
	check(Expedition.current_page=="SETTINGS","title settings receives a viewport click")
	check(Expedition.modal_shield.is_visible_in_tree() and InputBlocker.isActive(), "settings owns modal shield and input lock")
	await click(Expedition.panel.find_child("CloseMenu",true,false));await settle()
	check(not Expedition.panel.visible and not Expedition.modal_shield.visible and not InputBlocker.isActive(), "closing settings releases shield and input lock")
	await click(Expedition.art.ui.get_node("TitleStart"));await settle();await shot("03-selection")
	capture_geometry("selection",Expedition.panel)
	check(Expedition.panel.find_child("BeginExpedition",true,false)!=null,"title start enters selection")
	var selection_page = Expedition.menus.shell.canvas.get_instance_id()
	var selection_epoch = Expedition.popup_epoch
	var selection_art = Expedition.panel.find_child("Ref_selection",true,false).get_instance_id()
	await click(Expedition.panel.find_child("RoleNext",true,false));await settle();await shot("04-selection-archer")
	check(Expedition.menus.runs.role=="archer","carousel changes draft role")
	check(Expedition.menus.shell.canvas.get_instance_id()==selection_page and Expedition.popup_epoch==selection_epoch and Expedition.panel.find_child("Ref_selection",true,false).get_instance_id()==selection_art,"carousel swaps the hero in place without rebuilding page or background")
	await click(Expedition.panel.find_child("ChooseLoadout",true,false));await settle()
	await click(Expedition.panel.find_child("ChooseDifficulty",true,false));await settle()
	check(Expedition.popup_epoch==selection_epoch,"loadout and difficulty cycles keep the same page")
	await click(Expedition.panel.find_child("RolePrevious",true,false));await settle()
	await click(Expedition.panel.find_child("BeginExpedition",true,false));await settle()
	Expedition.flow.skip_tutorial()
	if Expedition.flow.screen_state=="ROUTE_SELECT":Expedition.flow.choose_route(0)
	await settle();await shot("05-shop")
	capture_geometry("shop",Expedition.art.ui)
	capture_geometry("shop-scenery",Expedition.art.scenery)
	var sign=Expedition.art.ui.get_node("ArtStartBattle")
	check_caption_block([sign.get_node("StageCaption"),sign.get_node("StageNumber")],sign,"shop start sign")
	check_caption(caption_of(Expedition.art.ui.get_node("Offer0/PriceTag"),"Price"),Expedition.art.ui.get_node("Offer0/PriceTag"),"shop price tag",false)
	check(Game.state==Game.State.Shop,"new selection reaches native shop")
	check(Expedition.hud_layer.get_instance_id() == hud_id and Expedition.overlay.get_instance_id() == dialog_id, "same HUD and dialog shell survive entering shop")
	check(Expedition.status.text == Expedition.t("ui.run_header", {"act": int(Expedition.flow.run.act), "step": int(Expedition.flow.run.step), "hp": ceili(float(Expedition.flow.run.health)), "max_hp": ceili(float(Expedition.flow.run.max_health)), "gold": int(Expedition.flow.run.gold)}), "HUD observes the authoritative run header")
	check(Game.STORAGEBOX.has_meta("art_storage_slots"),"storage uses squares painted on the supplied cloth")
	check(not is_instance_valid(Game.STORAGEBOX.pve_slot_root) or Game.STORAGEBOX.pve_slot_root.get_children().all(func(child):return child is ColorRect),"no added storage grid or numeric labels")
	var offer: Item = Game.shopSceneNode.slots[0].item
	if is_instance_valid(offer):
		offer.gainFocus()
		await settle()
		check(is_instance_valid(offer.tooltip) and offer.tooltip.texture.resource_path.ends_with("/tooltip_paper.png"),"actual shop tooltip uses the supplied parchment")
		await shot("05b-shop-tooltip")
		offer.loseFocus()
	var original=Expedition.flow.run.build.duplicate(true)
	var generation=int(Expedition.flow.run.shop.get("refresh_count",0))
	await click(Expedition.art.ui.get_node("Action_refresh"));await settle();await shot("06-refresh")
	check(int(Expedition.flow.run.shop.refresh_count)>generation,"new refresh target changes actual shop generation")
	for index in Game.shopSceneNode.slots.size():
		var data=Expedition.bridge.slot_data(index)
		check(str(Game.shopSceneNode.slots[index].item.get_meta("pve_definition_id",""))==str(data.definition_id),"refresh synchronizes actual offer "+str(index))
	Expedition.show_codex();await settle();await shot("07-book-items")
	check(Expedition.menus.library.matches.size()==Expedition.db.rows("items").size(),"catalogue uses actual item definitions")
	await click(Expedition.panel.find_child("ListNext",true,false));await settle()
	check(Expedition.menus.library.page==1,"book next button changes entries")
	var book = Expedition.menus.library
	book.query = "no_such_codex_entry_20261106"
	book.populate()
	check(book.matches.is_empty() and book.page == 0, "unmatched query clears results and clamps the old page")
	book.query = ""
	book.populate()
	await click(Expedition.panel.find_child("BookPoolFilter", true, false));await settle()
	check(book.owner_filter == "public" and not book.matches.is_empty() and book.matches.all(
		func(row): return str(row.definition.get("owner_pool", "public")) == "public"), "pool filter exposes only public catalogue entries")
	await click(Expedition.panel.find_child("BookTab_bags",true,false));await settle();await shot("08-book-bags")
	var wheel=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=Vector2(1180,420)
	get_viewport().push_input(wheel,true);await settle()
	check(Expedition.menus.library.rotation==90,"blueprint rotates read-only geometry with the shop wheel control")
	await click(Expedition.panel.find_child("BookTab_recipes",true,false));await settle();await shot("09-book-recipes")
	await click(Expedition.panel.find_child("BookCraftableFilter",true,false));await settle()
	check(book.matches.all(func(row): return not row.candidate.is_empty()),
		"craftable chapter exposes only candidates returned by the original service")
	await click(Expedition.panel.find_child("BookTab_bags",true,false));await settle()
	check(Expedition.menus.library.matches.size()==Expedition.db.release_catalog.bags.size(),"recipe-only craftable filter never hides another chapter")
	await click(Expedition.panel.find_child("BookTab_enemies",true,false));await settle();await shot("10-book-enemies")
	await click(Expedition.panel.find_child("BookTab_characters",true,false));await settle();await shot("10b-book-heroes")
	check(book.matches.size()==Expedition.db.rows("characters").size(),"hero catalogue uses actual role definitions")
	check(Expedition.flow.run.build==original,"all catalogue interactions preserve inventory")
	await click(Expedition.panel.find_child("CloseMenu",true,false));await settle()
	await click(Expedition.art.ui.get_node("ArtStartBattle"));await settle();await shot("11-combat")
	capture_geometry("combat",Expedition.art.ui)
	geometry["grid_origins"]=[Game.PLAYER.INVENTORY.tilemap.global_position,Game.OPPONENT.INVENTORY.tilemap.global_position]
	check_caption(caption_of(Expedition.art.ui.get_node("CombatSpeed"),"SpeedCaption"),Expedition.art.ui.get_node("CombatSpeed"),"combat speed")
	check(Game.state==Game.State.Combat,"new hanging sign starts native combat")
	check(Expedition.hud_layer.get_instance_id() == hud_id and Expedition.overlay.get_instance_id() == dialog_id, "same HUD and dialog shell survive combat")
	if Game.state==Game.State.Combat:
		await click(Expedition.art.ui.get_node("CombatPauseTarget"));await settle()
		check(Expedition.flow.combat_paused,"new pause target pauses playback")
		await click(Expedition.art.ui.get_node("CombatSpeed"));await settle()
		await click(Expedition.art.ui.get_node("Action_combat_settings"));await settle();await shot("12-combat-settings")
		await click(Expedition.panel.find_child("SaveAndExit",true,false));await settle();await shot("13-saved-title")
		var run_id=Expedition.flow.saves.load_save("run").data.run_id
		await click(Expedition.art.ui.get_node("TitleStart"));await settle()
		check(Expedition.flow.run.run_id==run_id,"main start resumes the same saved run")
	await Expedition.return_to_title();await settle()
	await click(Expedition.art.ui.get_node("TitleNewRun"));await settle()
	check(Expedition.flow.screen_state=="MAIN_MENU" and str(Expedition.flow.run.get("state",""))=="RUN_RESULT","ending the current run stays on the main title")
	await click(Expedition.art.ui.get_node("TitleStart"));await settle()
	await click(Expedition.panel.find_child("BeginExpedition",true,false));await settle()
	check(Expedition.flow.screen_state=="ROUTE_SELECT","explicit new game reaches route selection")
	Expedition.show_settings();await settle()
	await click(Expedition.panel.find_child("SaveAndExit",true,false));await settle()
	check(Expedition.art.ui.has_node("TitleNewRun"),"saving from a route rebuilds main-menu new-game control")
	var beginnings=Expedition.loading_screen.history.filter(func(row):return row.event=="begin").map(func(row):return row.reason)
	for reason in ["startup","new_expedition","enter_shop","shop_to_combat","continue_run","return_to_title"]:check(reason in beginnings,"shared progress bar covers "+reason)
	check(Expedition.loading_screen.layer>Expedition.art.curtain.layer,"progress bar is above cloud layer")
	check(not Expedition.loading_screen.visible,"progress bar releases input after loading")
	var file=FileAccess.open(output.path_join("reference-layout-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"geometry":geometry,"loading":Expedition.loading_screen.history},"\t"));file.close()
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
