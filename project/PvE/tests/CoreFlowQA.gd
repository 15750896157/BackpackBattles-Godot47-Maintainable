extends Node
var output = ""
var checks: Array = []
var failures: Array = []
var observations: Array = []
var player_copy = false
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg=="--core-flow-player-copy": player_copy=true
	call_deferred("run_tests")
func check(value, message):
	checks.append({"ok":bool(value),"message":message})
	if not value: failures.append(message);print("CORE_FAIL ",message)
	return bool(value)
func wait_for(predicate: Callable, seconds = 12.0) -> bool:
	var deadline = Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().process_frame
	return predicate.call()
func idle() -> bool:
	return not Expedition.syncing and not Expedition.entering_shop and not Expedition.combat_loading and not Expedition.art.curtain.busy and not Game.sceneAnimation.is_playing()
func settle():
	for frame in 4: await get_tree().process_frame
	await wait_for(idle,25.0)
	await get_tree().create_timer(0.3,true,false,true).timeout
func note(label):
	var row={"phase":label,"screen":Expedition.flow.screen_state,"native":Game.state,"page":Expedition.current_page,"panel":Expedition.panel.visible,"pending":Expedition.render_pending,"syncing":Expedition.syncing,"curtain":Expedition.art.curtain.busy,"input_sources":InputBlocker.curSources,"title_mode":Game.titleScreen.process_mode,"ranked_filter":Game.titleScreen.rankedButton.mouse_filter,"ranked_disabled":Game.titleScreen.rankedButton.disabled,"scene_animation":Game.sceneAnimation.current_animation,"stream":AssetStream.stats()}
	observations.append(row);print("CORE_OBSERVATION ",JSON.stringify(row))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
func shelf_matches() -> bool:
	for index in Game.shopSceneNode.slots.size():
		var offer=Game.shopSceneNode.slots[index]
		var data=Expedition.bridge.slot_data(index)
		if data.is_empty() or bool(data.get("sold",false)): continue
		if not is_instance_valid(offer.item) or str(offer.item.get_meta("pve_definition_id","")) != str(data.definition_id): return false
	return true
func press_text(caption: String) -> bool:
	for control in Expedition.panel.find_children("*","Button",true,false):
		if (control.text == caption or str(control.get_meta("action_caption",""))==caption) and not control.disabled:
			if player_copy: await click_control(control)
			else: control.pressed.emit()
			return true
	return false
func click_control(control: Control):
	if Expedition.popup_content.is_ancestor_of(control):
		Expedition.popup_scroll.ensure_control_visible(control)
		await get_tree().process_frame
		await get_tree().process_frame
	var point=control.get_global_transform_with_canvas()*(control.size*0.5)
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;event.global_position=point
		get_viewport().push_input(event,true)
		await get_tree().process_frame
func resume_from_title():
	if player_copy:await click_control(Game.titleScreen.rankedButton)
	else:Game.titleScreen.rankedButton.pressed.emit()
	await settle()
	var resume=Expedition.panel.find_child("ResumeSavedRun",true,false)
	if not check(resume!=null,"standard entrance offers saved run"):return
	if player_copy:await click_control(resume)
	else:resume.pressed.emit()
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	if not await wait_for(func():return Expedition.initialized,90.0): check(false,"initialize");finish();return
	await settle()
	if player_copy:
		await resume_from_title()
	else:
		check(Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true).ok,"new isolated run")
		Expedition.flow.skip_tutorial();await settle()
		check(Expedition.flow.choose_route(0).ok,"route enters shop")
	await settle();await note("01-shop")
	check(Game.state==Game.State.Shop and shelf_matches(),"initial visible shelf matches authoritative offers")
	if Expedition.art.ui==null: finish();return
	# The user's normal item drag must precede refresh/result checks: signal-only
	# runs miss the deferred update that happens while the drop owns syncing.
	var held=Game.PLAYER.INVENTORY.getItems().filter(func(item):return not item.isBag())[0]
	var origin=Expedition.flow.placement.find(Expedition.flow.run.build,str(held.get_meta("pve_uid"))).entry.duplicate(true)
	held.pickup()
	Game.PLAYER.INVENTORY.orientItem(held,Vector2(origin.x,origin.y),int(origin.rotation)/90)
	var drop=held.drop();held.reactToDropResult(drop)
	check(drop==Item.DropResult.AddedToInventory,"native drag and drop commits through original interaction")
	check(await wait_for(func():return idle() and not Expedition.bridge.drop_pending and not Expedition.render_pending,3.0),"drop resumes its deferred presentation update")
	await note("01b-after-native-drop")
	for index in range(3):
		Expedition.flow.run.free_refreshes=3
		var before=Expedition.flow.run.shop.duplicate(true)
		if player_copy: await click_control(Expedition.art.ui.get_node("Action_refresh"))
		else: Expedition.art.ui.get_node("Action_refresh").pressed.emit()
		var matched=await wait_for(func(): return idle() and shelf_matches(),6.0)
		await settle()
		check(Expedition.flow.run.shop!=before,"refresh changes authoritative offers "+str(index))
		check(matched and shelf_matches(),"refresh swaps visible item scenes with their prices "+str(index))
		await note("02-refresh-"+str(index))
	check(not Expedition.render_pending,"no stranded render request after refresh")
	if Expedition.flow.run.current_node.get("type","")=="merchant":
		Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
		check(await wait_for(func():return Expedition.flow.screen_state=="ROUTE_SELECT",4.0),"merchant leaves through its normal route flow")
		await settle()
		var combat_route=-1
		for index in Expedition.flow.run.route_candidates.size():
			if str(Expedition.flow.run.route_candidates[index].type).ends_with("combat"):combat_route=index;break
		if combat_route<0:check(false,"next combat route available");finish();return
		Expedition.flow.choose_route(combat_route);await settle()
	Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
	check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle(),25.0),"start battle through visible art control")
	Expedition.set_playback(4.0,false)
	check(await wait_for(func():return Expedition.flow.screen_state=="COMBAT_RESULT",45.0),"ordinary playback reaches battle end")
	check(await wait_for(func():return Expedition.panel.visible and Expedition.current_page=="COMBAT_RESULT",3.0),"result automatically opens without touching intel")
	await settle()
	await note("03-automatic-result")
	if Expedition.current_page=="COMBAT_RESULT":
		for control in Expedition.popup_content.find_children("*","Button",true,false):
			if control.text==Expedition.t("ui.next"):check(Expedition.popup_scroll.get_global_rect().encloses(control.get_global_rect()),"next step is on the first visible page above long statistics")
		check(await press_text(Expedition.t("ui.next")),"result next button is available")
		check(await wait_for(func():return Expedition.current_page in ["REWARD_SELECT","RUN_RESULT"],4.0),"result next reaches rewards or run result")
	await Expedition.return_to_title();await settle();await note("04-title-after-result")
	check(not InputBlocker.isActive(),"title has no transition or menu input shield")
	Game.titleScreen.rankedButton.pressed.emit();await settle()
	check(Expedition.current_page=="SETUP" and Expedition.panel.visible,"new-game title banner opens setup after battle")
	Expedition.create_run("armorer","armorer_blades","tutorial",1340,true)
	check(await wait_for(func():return Expedition.current_page=="ROUTE_SELECT",4.0),"new game actually leaves setup and shows routes")
	if Expedition.render_pending: finish();return
	Expedition.close_popup();await settle()
	check(Expedition.flow.new_run("armorer","armorer_blades","tutorial",1340,true).ok,"second fresh run")
	Expedition.flow.skip_tutorial();await settle()
	Expedition.flow.choose_route(0);await settle()
	Expedition.show_settings();await settle()
	check(await press_text(Expedition.t("ui.save_menu")),"save current shop through settings")
	await settle()
	await resume_from_title()
	check(await wait_for(func():return Game.state==Game.State.Shop and Expedition.flow.screen_state=="SHOP_PREPARE" and idle() and not Expedition.render_pending,25.0),"title continue restores saved shop without a manual redraw")
	Expedition.art.ui.get_node("ArtStartBattle").pressed.emit()
	check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle(),25.0),"second combat entered")
	Expedition.art.ui.get_node("Action_pause").pressed.emit()
	check(Expedition.flow.combat_paused,"pause button stops playback before exit")
	Expedition.art.ui.get_node("Action_combat_settings").pressed.emit();await settle()
	check(await press_text(Expedition.t("ui.save_menu")),"save and exit button in live combat settings")
	await settle();await note("05-title-after-combat-exit")
	check(Game.state==Game.State.Title and idle(),"combat exit finishes title transition")
	check(not InputBlocker.isActive() and Game.titleScreen.rankedButton.mouse_filter!=Control.MOUSE_FILTER_IGNORE,"title buttons accept real pointer input after combat exit")
	await resume_from_title()
	check(await wait_for(func():return Game.state==Game.State.Combat and Expedition.native_battle_ready and idle(),25.0),"continue button reconstructs exited combat")
	await note("06-continue")
	await Expedition.return_to_title();await settle()
	finish()
func finish():
	var file=FileAccess.open(output.path_join("core-flow-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations},"\t"));file.close()
	print("CORE_FLOW_QA ",checks.size()," failures=",failures)
	Game._begin_shutdown();await AssetStream.drain()
	await get_tree().create_timer(0.12,true,false,true).timeout
	get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
