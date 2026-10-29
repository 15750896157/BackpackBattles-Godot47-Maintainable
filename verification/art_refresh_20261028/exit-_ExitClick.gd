extends Node
var output=""
var checks:Array=[]
var failures:Array=[]
var pressed=false
func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")
func check(value,message):
	checks.append({"ok":bool(value),"message":message})
	if not value:failures.append(message)
func click(point):
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;get_viewport().push_input(motion,true)
	for down in [true,false]:
		await get_tree().process_frame
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;get_viewport().push_input(event,true)
func record():
	var file=FileAccess.open(output.path_join("exit-click-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok":failures.is_empty() and pressed,"checks":checks,"failures":failures,"actual_exit_signal":pressed,"game_shutdown_started":Game.quitting,"input_kind":"Godot viewport mouse events; no physical pointer input"},"\t"));file.close()
func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	while not Expedition.initialized:await get_tree().process_frame
	while Game.sceneAnimation.is_playing():await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	var root=Game.titleScreen.get_node("Node2D/Background/Quit")
	var button=root.get_node("QuitButton");var label=root.get_node("Node2D/QuitLabel")
	for offset in [Vector2.ZERO,Vector2(-60,0),Vector2(60,0),Vector2(0,-12),Vector2(0,12)]:
		var point=label.get_global_transform_with_canvas()*(label.size*0.5+offset)
		check(Rect2(Vector2.ZERO,button.size).has_point(button.get_global_transform_with_canvas().affine_inverse()*point),"visible label point inside native exit target: "+str(offset))
	var left=Vector2(1425,900)
	check(not Rect2(Vector2.ZERO,button.size).has_point(button.get_global_transform_with_canvas().affine_inverse()*left),"left blank area is outside native exit target")
	await click(left)
	for frame in 3:await get_tree().process_frame
	check(not Game.quitting,"left blank click does not quit")
	button.pressed.connect(func():pressed=true;check(Game.quitting,"real native quit handler starts shutdown");record())
	await click(label.get_global_transform_with_canvas()*(label.size*0.5))
	await get_tree().create_timer(2.0,true,false,true).timeout
	if not pressed:
		check(false,"visible label click did not activate native exit");record();Game._begin_shutdown();await AssetStream.drain();get_tree().quit(1)
