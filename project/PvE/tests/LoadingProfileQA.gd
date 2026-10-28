extends Node

var output = ""
var samples: Array = []
var initialized_ms = 0

func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func frames(count):
	for index in count: await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func snapshot(label: String):
	var cached = 0
	for nodes in ObjectPool.instances.values(): cached += nodes.size()
	var resident_scenes = 0
	for descriptor in ItemBook.items.values():
		var scene = descriptor.peek_scene() if descriptor.has_method("peek_scene") else descriptor.scene
		if scene != null: resident_scenes += 1
	var metrics = {"label": label, "time_ms": Time.get_ticks_msec(),
		"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"static_peak_bytes": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"tree_nodes": get_tree().get_node_count(),
		"orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"stream": AssetStream.stats(), "backgrounds": Expedition.scenery.live.keys(),
		"geometry_cache": Expedition.bridge.footprint_layout.pictures.size(),
		"cached_pool_nodes": cached, "prepared_instances": ItemBook.preparedItemInstances.size(),
		"resident_item_scenes": resident_scenes, "texture_cache": Expedition.bindings.texture_cache.size()}
	var durations: Array = []
	for index in 120:
		var started = Time.get_ticks_usec()
		await get_tree().process_frame
		durations.append(float(Time.get_ticks_usec() - started) / 1000.0)
	durations.sort()
	metrics["frame_median_ms"] = durations[60]
	metrics["frame_p95_ms"] = durations[114]
	metrics["frame_p99_ms"] = durations[118]
	samples.append(metrics)
	print("LOADING_PROFILE ", label, " ", JSON.stringify(metrics))

func export_catalog():
	var catalog: Dictionary = {}
	for descriptor in ItemBook.items.values():
		var path = descriptor.scene_path if "scene_path" in descriptor else descriptor.scene.resource_path if descriptor.scene != null else ""
		var animation = descriptor.animation_path if "animation_path" in descriptor else descriptor.animationScene.resource_path if descriptor.animationScene != null else ""
		catalog[descriptor.identifier] = {"scene": path, "animation": animation, "sockets": ItemBook.numSockets[descriptor.itemIndex]}
	var file = FileAccess.open(output.path_join("asset-catalog.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": 1, "items": catalog}, "\t"));file.close()

func run_tests():
	var started = Time.get_ticks_msec()
	while not Expedition.initialized:
		if Time.get_ticks_msec() - started > 90000: get_tree().call_deferred("quit", 2);return
		await get_tree().process_frame
	initialized_ms = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(output)
	print("PROFILE_INITIALIZED ", initialized_ms)
	export_catalog()
	await snapshot("title_initial")
	await frames(850)
	await snapshot("title_idle")
	Expedition.perform(Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 92141, true))
	await frames(10)
	Expedition.perform(Expedition.flow.choose_route(0))
	await get_tree().create_timer(6.0).timeout
	await snapshot("shop")
	Expedition.show_codex()
	await frames(120)
	await snapshot("codex")
	Expedition.close_popup()
	await frames(120)
	await snapshot("codex_closed")
	Expedition.return_to_title()
	await frames(180)
	await snapshot("title_returned")
	var file = FileAccess.open(output.path_join("loading-profile.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"initialized_ms": initialized_ms, "samples": samples}, "\t"));file.close()
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit")
