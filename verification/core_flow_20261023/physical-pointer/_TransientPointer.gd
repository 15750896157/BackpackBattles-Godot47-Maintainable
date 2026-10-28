extends Node
var output=""
var phase="preparing"
var fixture_ready=false
var changing=false
var clock=0.0
var started=0
var checks={"refreshed_visible_items":false,"battle_started":false,"automatic_result":false,"next_to_rewards":false,"saved_combat_to_title":false,"continued_combat":false,"new_game_setup":false,"new_game_routes":false}
var refresh_count=0
var captured={}
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("prepare")
func idle():await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
func prepare():
	while not Expedition.initialized:await get_tree().process_frame
	Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0);await idle()
	var item=Game.PLAYER.INVENTORY.getItems().filter(func(entry):return not entry.isBag())[0]
	var entry=Expedition.flow.placement.find(Expedition.flow.run.build,str(item.get_meta("pve_uid"))).entry
	item.pickup();Game.PLAYER.INVENTORY.orientItem(item,Vector2(entry.x,entry.y),int(entry.rotation)/90)
	item.reactToDropResult(item.drop());await idle()
	refresh_count=int(Expedition.flow.run.shop.refresh_count)
	DisplayServer.window_set_title("Core Flow Pointer QA - isolated saves")
	phase="refresh_and_fight";fixture_ready=true;started=Time.get_ticks_msec()
func shelf_matches():
	for index in Game.shopSceneNode.slots.size():
		var data=Expedition.bridge.slot_data(index);var item=Game.shopSceneNode.slots[index].item
		if bool(data.get("sold",false)):continue
		if not is_instance_valid(item) or str(item.get_meta("pve_definition_id",""))!=str(data.get("definition_id","")):return false
	return true
func capture(label):
	if captured.has(label):return
	captured[label]=true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
func _process(delta):
	if not fixture_ready:return
	clock+=delta
	if clock<0.1:return
	clock=0
	if not changing:
		var state=Expedition.flow.screen_state
		if phase=="refresh_and_fight":
			if state=="SHOP_PREPARE" and int(Expedition.flow.run.shop.refresh_count)>refresh_count and not Expedition.syncing and not Expedition.render_pending and shelf_matches():checks.refreshed_visible_items=true
			if state=="COMBAT_RUNNING" and Expedition.native_battle_ready and not Expedition.art.curtain.busy:
				if not checks.battle_started:Expedition.set_playback(4.0,false)
				checks.battle_started=true
			if state=="COMBAT_RESULT" and Expedition.current_page=="COMBAT_RESULT" and Expedition.panel.visible:checks.automatic_result=true;capture("automatic-result")
			if state=="REWARD_SELECT":
				checks.next_to_rewards=true;changing=true;call_deferred("prepare_exit")
		elif phase=="exit_combat" and state=="MAIN_MENU" and Game.state==Game.State.Title and not Expedition.art.curtain.busy:
			checks.saved_combat_to_title=not InputBlocker.isActive();phase="continue_combat"
		elif phase=="continue_combat" and state=="COMBAT_RUNNING" and Expedition.native_battle_ready and not Expedition.art.curtain.busy:
			checks.continued_combat=true;changing=true;call_deferred("prepare_title")
		elif phase=="new_game":
			if Expedition.current_page=="SETUP":checks.new_game_setup=true
			if state=="ROUTE_SELECT" and Expedition.current_page=="ROUTE_SELECT":checks.new_game_routes=true;capture("new-game-routes")
	var file=FileAccess.open(output.path_join("pointer-state.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ready":fixture_ready,"phase":phase,"changing":changing,"checks":checks,"all_passed":not checks.values().has(false),"page":Expedition.current_page,"screen":Expedition.flow.screen_state,"pending":Expedition.render_pending,"input_sources":InputBlocker.curSources},"\t"));file.close()
	if FileAccess.file_exists(output.path_join("stop.txt")) or Time.get_ticks_msec()-started>360000:
		fixture_ready=false;call_deferred("finish")
func prepare_exit():
	await Expedition.return_to_title();await idle()
	Expedition.flow.new_run("armorer","armorer_blades","tutorial",1340,true)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0);await idle()
	Game.startCombatButton.activateButton();await idle()
	Expedition.set_playback(1.0,true)
	phase="exit_combat";changing=false
func prepare_title():
	await Expedition.return_to_title();await idle()
	phase="new_game";changing=false
func finish():
	Game._begin_shutdown();await AssetStream.drain()
	await get_tree().create_timer(0.12,true,false,true).timeout
	get_tree().call_deferred("quit")
