extends Node
## M0 scaffold contracts. Expected base-VM errors are isolated in a child process.
class TestVM extends ViewModel:
	func snapshot() -> Dictionary:
		return {"v":1}

const BASE_ERROR: String = "ViewModel.snapshot() 必须由子类实现"
var output: String = ""
var negative_base: bool = false
var checks: Array = []
var failures: Array = []
var router_signals: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
		if argument=="--scaffold-negative-base":negative_base=true
	call_deferred("run_tests")

func check(condition: bool, label: String) -> void:
	checks.append({"ok":condition,"label":label})
	if not condition:
		failures.append(label)
		print("CONTRACT_FAILURE ",label)
		push_error("CONTRACT_FAILURE "+label)

func write_report(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"));file.close()

func children_snapshot() -> Array:
	var values: Array = []
	for child in Game.mainNode.get_children():values.append([str(child.name),child.get_instance_id()])
	return values

func on_screen_changed(screen_id: StringName) -> void:
	router_signals.append(screen_id)

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	var deadline: int = Time.get_ticks_msec()+90000
	while not Expedition.initialized and Time.get_ticks_msec()<deadline:await get_tree().process_frame
	if not Expedition.initialized:
		check(false,"Main initialization completes within deadline");await finish(1);return
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	if "--game-api-snapshot" in OS.get_cmdline_user_args():
		capture_game_api()
	if negative_base:
		var base: ViewModel = ViewModel.new()
		var value: Dictionary = base.snapshot()
		write_report(output.path_join("negative-result.json"),{"returned_empty_dictionary":value.is_empty(),"expected_error":BASE_ERROR})
		await finish(0 if value.is_empty() else 2)
		return
	check(get_node_or_null("/root/SceneRouter")==SceneRouter,"SceneRouter autoload exists")
	var disabled_router = preload("res://Code/Runtime/Scene/RouterKernel.gd").new()
	add_child(disabled_router)
	check(disabled_router.change_scene(&"title") == ERR_UNAVAILABLE,"independent SceneRouter instance starts disabled")
	check(disabled_router.current_screen_id==&"","current screen starts empty")
	check(not disabled_router.is_registered(&"scaffold_unknown"),"unregistered screen returns false")
	var children: Array = children_snapshot()
	var current_scene: Node = get_tree().current_scene
	var state: Array = [Game.state,Expedition.flow.screen_state,Expedition.current_page]
	var uncached: String = "res://PvE/tests/__ScaffoldNoLoad__.tscn"
	check(not ResourceLoader.has_cached(uncached),"target resource is not cached before registration")
	disabled_router.register_screen(&"scaffold_probe",uncached)
	check(disabled_router.is_registered(&"scaffold_probe"),"disabled router supports memory-only registration")
	check(not ResourceLoader.has_cached(uncached),"registration never loads resources")
	disabled_router.screen_changed.connect(on_screen_changed)
	check(disabled_router.change_scene(&"scaffold_probe")==ERR_UNAVAILABLE,"registered change is unavailable")
	check(disabled_router.change_scene(&"scaffold_unknown")==ERR_UNAVAILABLE,"unknown change is unavailable")
	check(children_snapshot()==children and get_tree().current_scene==current_scene,"disabled calls preserve Main children and current scene")
	check([Game.state,Expedition.flow.screen_state,Expedition.current_page]==state,"disabled calls preserve game and domain states")
	check(router_signals.is_empty(),"disabled calls never emit screen_changed")
	check(disabled_router.current_screen_id==&"" and not ResourceLoader.has_cached(uncached),"disabled calls never assign or load screens")
	for frame in 2:await get_tree().process_frame
	check(children_snapshot()==children and router_signals.is_empty() and get_tree().current_scene==current_scene,"no deferred tree or signal effects")
	disabled_router.screen_changed.disconnect(on_screen_changed)
	disabled_router.queue_free()
	var vm: TestVM = TestVM.new()
	check(vm is ViewModel and vm is RefCounted,"QA-only subclass instantiates")
	check(vm.snapshot()=={"v":1},"subclass snapshot overrides the abstract method")
	var received: Dictionary = {"count":0}
	var callback: Callable = func():received.count+=1
	vm.changed.connect(callback)
	check(vm.changed.is_connected(callback),"changed signal is connectable")
	vm.changed.emit()
	check(received.count==1,"changed signal is deliverable")
	vm.changed.disconnect(callback)
	vm.changed.emit()
	check(received.count==1,"changed signal can disconnect")
	check_negative_base()
	write_report(output.path_join("scaffold-contracts.json"),{"ok":failures.is_empty(),"checks":checks,"failures":failures,"negative_error_isolated":true,"production_VM_instances":0})
	await finish(0 if failures.is_empty() else 1)

func check_negative_base() -> void:
	var child_directory: String = output.path_join("negative-base")
	DirAccess.make_dir_recursive_absolute(child_directory)
	var arguments: PackedStringArray = ["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",child_directory.path_join("game.log"),"res://PvE/tests/ScaffoldContractsMain.tscn","--","--qa-output="+child_directory,"--qa-save-directory="+child_directory.path_join("saves"),"--scaffold-negative-base"]
	var captured: Array = []
	var code: int = OS.execute(OS.get_executable_path(),arguments,captured,true)
	var file: FileAccess = FileAccess.open(child_directory.path_join("captured-output.log"),FileAccess.WRITE)
	file.store_string("\n".join(captured));file.close()
	# 中文 Windows 上 OS.execute 的管道捕获按系统码页（GBK）解码，UTF-8 中文会变乱码；
	# 判据取证改用子进程自己写的 UTF-8 日志文件，严格程度不变。
	var diagnostics: String = FileAccess.get_file_as_string(child_directory.path_join("game.log"))
	var result_path: String = child_directory.path_join("negative-result.json")
	var result = JSON.parse_string(FileAccess.get_file_as_string(result_path)) if FileAccess.file_exists(result_path) else null
	check(code==0,"base-VM negative child completes successfully")
	check(result is Dictionary and bool(result.get("returned_empty_dictionary",false)),"base snapshot returns empty dictionary in isolated child")
	check(diagnostics.contains(BASE_ERROR),"base snapshot emits its required error")
	check(diagnostics.count("ERROR:")==1 and not diagnostics.contains("SCRIPT ERROR:"),"child has exactly the expected error and no unrelated failures")
	write_report(child_directory.path_join("process-validation.json"),{"exit_code":code,"expected_error_count":diagnostics.count("ERROR:"),"script_errors":diagnostics.contains("SCRIPT ERROR:"),"expected_message_found":diagnostics.contains(BASE_ERROR)})

func capture_game_api() -> void:
	var methods := {}
	for method in Game.get_method_list():
		var name := str(method.name)
		if not name.begins_with("@"):
			methods[name] = {"args": method.args, "defaults": method.default_args, "return": method.get("return"), "flags": method.flags}
	var properties := {}
	for property in Game.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			properties[property.name] = {"type": property.type, "class_name": property.get("class_name"), "usage": property.usage}
	var signals := {}
	for declaration in Game.get_signal_list():
		signals[declaration.name] = declaration.args
	write_report(output.path_join("game-api.json"), {
		"methods": methods, "properties": properties, "signals": signals,
		"version": Game.VERSION, "state": Game.state, "classes": Game.getClassKeys(),
		"skin_slots": Game.SkinSlot, "damage_stacks": Game.getStacks(),
		"native_anchors": [str(Game.playerNode.get_path()), str(Game.shopSceneNode.get_path()),
			str(Game.combatSceneNode.get_path()), str(Game.UINode.get_path())],
	})

func finish(code: int):
	Game._begin_shutdown()
	await AssetStream.drain()
	get_tree().call_deferred("quit",code)
