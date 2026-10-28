extends Node
var output=""
var ready_for_input=false
var checks={"open_guide":false,"close_graphical":false,"list_next":false,"list_previous":false,"rotate_held":false,"return_held":false,"real_drag_drop":false,"saved_to_title":false,"resume_choice":false,"continued_shop":false,"new_draft":false,"new_game_routes":false}
var old_drop=0.0
var rotation=0.0
var tracked_item
var was_held=false
var first_run=""
var ticks=0.0
var started=0
var original_build={}
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("prepare")
func prepare():
	while not Expedition.initialized:await get_tree().process_frame
	Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0)
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	first_run=Expedition.flow.run.run_id;original_build=Expedition.flow.run.build.duplicate(true)
	old_drop=Game.lastItemDropTime
	DisplayServer.window_set_title("Touch UI Pointer QA - isolated saves")
	started=Time.get_ticks_msec();ready_for_input=true
func _process(delta):
	if not ready_for_input:return
	ticks+=delta
	if ticks<0.15:return
	ticks=0.0
	if Expedition.current_page=="UI_GUIDE":checks.open_guide=true
	if checks.open_guide and not Expedition.panel.visible:checks.close_graphical=true
	if Expedition.current_page=="CODEX":
		if Expedition.menus.library.page==1:checks.list_next=true
		if checks.list_next and Expedition.menus.library.page==0:checks.list_previous=true
	if is_instance_valid(Game.draggedItem):
		was_held=true
		if tracked_item!=Game.draggedItem:tracked_item=Game.draggedItem;rotation=tracked_item.rotation
		elif not is_equal_approx(tracked_item.rotation,rotation):checks.rotate_held=true
	elif was_held:
		if checks.rotate_held and Expedition.flow.run.build==original_build:checks.return_held=true
		if Game.lastItemDropTime>old_drop and not Expedition.render_pending and not Expedition.syncing:checks.real_drag_drop=true
	var state=Expedition.flow.screen_state
	if state=="MAIN_MENU" and Game.state==Game.State.Title and not Expedition.art.curtain.busy:checks.saved_to_title=true
	if checks.saved_to_title and Expedition.current_page=="SETUP" and Expedition.panel.find_child("ResumeSavedRun",true,false)!=null:checks.resume_choice=true
	if checks.resume_choice and state=="SHOP_PREPARE" and Expedition.flow.run.run_id==first_run and not Expedition.syncing and not Expedition.art.curtain.busy:checks.continued_shop=true
	if checks.continued_shop and Expedition.current_page=="SETUP" and Expedition.panel.find_child("BeginExpedition",true,false)!=null:checks.new_draft=true
	if checks.new_draft and state=="ROUTE_SELECT" and Expedition.flow.run.run_id!=first_run:checks.new_game_routes=true
	var file=FileAccess.open(output.path_join("pointer-state.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"all_passed":not checks.values().has(false),"page":Expedition.current_page,"screen":state,"held":is_instance_valid(Game.draggedItem),"pending":Expedition.render_pending},"\t"));file.close()
	if FileAccess.file_exists(output.path_join("stop.txt")) or Time.get_ticks_msec()-started>1800000:
		ready_for_input=false;call_deferred("finish")
func finish():
	Game._begin_shutdown();await AssetStream.drain()
	get_tree().call_deferred("quit")
