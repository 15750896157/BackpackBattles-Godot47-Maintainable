extends Node
var output=""
var prepared=false
var checks={"picked_up":false,"rotated_while_held":false,"returned_original_placement":false,"valid_build_after_return":false}
var original={}
var tracked
var start_angle=0.0
var was_held=false
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("prepare")
func canonical(build:Dictionary)->Dictionary:
	var result=build.duplicate(true)
	for layer in ["bags","items","storage"]:result[layer].sort_custom(func(a,b):return str(a.uid)<str(b.uid))
	return result
func prepare():
	while not Expedition.initialized:await get_tree().process_frame
	Expedition.flow.new_run("armorer","armorer_blades","tutorial",1337,true)
	Expedition.flow.skip_tutorial();Expedition.flow.choose_route(0)
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	original=canonical(Expedition.flow.run.build)
	var file=FileAccess.open(output.path_join("original-build.json"),FileAccess.WRITE);file.store_string(JSON.stringify(original,"\t"));file.close()
	DisplayServer.window_set_title("Touch Return Pointer QA - isolated saves");prepared=true
func _process(_delta):
	if not prepared:return
	if is_instance_valid(Game.draggedItem):
		if not was_held:tracked=Game.draggedItem;start_angle=tracked.rotation;was_held=true;checks.picked_up=true
		if not is_equal_approx(tracked.rotation,start_angle):checks.rotated_while_held=true
	elif was_held:
		# Only the immediate held -> returned edge can satisfy this assertion.
		# Starting a later run can never overwrite this result.
		was_held=false
		if checks.rotated_while_held:
			checks.returned_original_placement=canonical(Expedition.flow.run.build)==original
			checks.valid_build_after_return=Expedition.flow.placement.validate(Expedition.flow.run.build).ok
			var file=FileAccess.open(output.path_join("returned-build.json"),FileAccess.WRITE);file.store_string(JSON.stringify(canonical(Expedition.flow.run.build),"\t"));file.close()
	var file=FileAccess.open(output.path_join("pointer-state.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"all_passed":not checks.values().has(false),"held":is_instance_valid(Game.draggedItem)},"\t"));file.close()
	if FileAccess.file_exists(output.path_join("stop.txt")):prepared=false;call_deferred("finish")
func finish():
	Game._begin_shutdown();await AssetStream.drain();get_tree().call_deferred("quit")
