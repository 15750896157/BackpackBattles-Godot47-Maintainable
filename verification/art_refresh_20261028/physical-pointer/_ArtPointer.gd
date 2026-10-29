extends Node
var output=""
var ready_for_input=false
var checks={"guide_open":false,"guide_close":false,"rotate":false,"return_unchanged":false,"drag_to_storage":false,"sell":false,"undo_sale":false,"refresh_instances":false,"save_title":false,"continue_run":false,"left_blank_no_exit":false,"exit_pressed":false}
var original_build={}
var run_id=""
var uid=""
var shop_signature=""
var held_before=false
var held_rotation=0.0
var clock=0.0
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("prepare")
func prepare():
	while not Expedition.initialized:await get_tree().process_frame
	Game.sceneAnimation.advance(100)
	Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0)
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	run_id=Expedition.flow.run.run_id;original_build=Expedition.flow.run.build.duplicate(true)
	for item in original_build.items:
		if item.definition_id=="utility_knife":uid=item.uid
	shop_signature=signature()
	var exit_button=Game.titleScreen.get_node("Node2D/Background/Quit/QuitButton")
	exit_button.pressed.connect(func():checks.exit_pressed=true;record())
	DisplayServer.window_set_title("New Art Pointer QA - isolated saves")
	ready_for_input=true
func signature():
	return str(Expedition.flow.run.get("shop",{}).get("slots",[]).map(func(slot):return slot.get("definition_id","")))
func _input(event):
	if ready_for_input and Game.state==Game.State.Title and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and Rect2(1365,855,100,90).has_point(event.position):
		checks.left_blank_no_exit=not Game.quitting
func _process(delta):
	if not ready_for_input:return
	clock+=delta
	if clock<0.1:return
	clock=0.0
	if Expedition.current_page=="UI_GUIDE":checks.guide_open=true
	if checks.guide_open and not Expedition.panel.visible:checks.guide_close=true
	var held=is_instance_valid(Game.draggedItem)
	if held and not held_before:held_rotation=Game.draggedItem.rotation
	if held and not is_equal_approx(Game.draggedItem.rotation,held_rotation):checks.rotate=true
	if held_before and not held and checks.rotate and Expedition.flow.run.build==original_build:checks.return_unchanged=true
	held_before=held
	var build=Expedition.flow.run.get("build",{})
	var stored=build.get("storage",[]).any(func(item):return str(item.uid)==uid)
	var carried=build.get("items",[]).any(func(item):return str(item.uid)==uid)
	if stored:checks.drag_to_storage=true
	if checks.drag_to_storage and not stored and not carried and int(Expedition.flow.run.get("gold",0))>8:checks.sell=true
	if checks.sell and stored:checks.undo_sale=true
	if Game.state==Game.State.Shop and signature()!=shop_signature:checks.refresh_instances=true
	if Game.state==Game.State.Title and Expedition.flow.screen_state=="MAIN_MENU" and not Expedition.art.curtain.busy:checks.save_title=true
	if checks.save_title and Game.state==Game.State.Shop and str(Expedition.flow.run.run_id)==run_id and not Expedition.syncing:checks.continue_run=true
	record()
	if FileAccess.file_exists(output.path_join("stop.txt")):
		ready_for_input=false;Game._begin_shutdown();await AssetStream.drain();get_tree().quit()
func record():
	var file=FileAccess.open(output.path_join("pointer-state.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"all_passed":not checks.values().has(false),"page":Expedition.current_page,"state":Expedition.flow.screen_state,"gold":Expedition.flow.run.get("gold",0),"held":is_instance_valid(Game.draggedItem),"quitting":Game.quitting},"\t"));file.close()
