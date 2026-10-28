extends SceneTree

var checks = 0
var failures: Array = []
func _init(): call_deferred("run")
func trace(value: String):
	var file = FileAccess.open("res://tools_ui_trace.txt", FileAccess.READ_WRITE if FileAccess.file_exists("res://tools_ui_trace.txt") else FileAccess.WRITE)
	file.seek_end(); file.store_line(value); file.close()
func json_equal(first, second) -> bool:
	if typeof(first) in [TYPE_INT, TYPE_FLOAT] and typeof(second) in [TYPE_INT, TYPE_FLOAT]:
		# Godot JSON parsing can round decimal 14.4 to the adjacent double.
		# Integer IDs/seeds remain exact; exported averages tolerate only 1e-12.
		return absf(float(first) - float(second)) <= 0.000000000001
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size(): return false
		for key in first:
			if not second.has(key) or not json_equal(first[key], second[key]): return false
		return true
	if first is Array and second is Array:
		if first.size() != second.size(): return false
		for index in first.size():
			if not json_equal(first[index], second[index]): return false
		return true
	return first == second
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label); printerr("TOOLS_UI_FAIL ", label)
func run():
	trace("begin")
	root.size = Vector2i(1440, 900)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var scene = load("res://PvE/Rules/tools/DeveloperTools.tscn").instantiate()
	trace("instantiated")
	root.add_child(scene)
	trace("ready")
	await process_frame; await process_frame
	check(not root.has_node("Game"), "tool scene has no original Game autoload")
	check(scene.snapshots[0].get("ok", false) and scene.snapshots[1].get("ok", false), "both initial configured snapshots ready")
	trace("initialized")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools_inspector.png")
	scene.side_picker.select(1); scene._populate_sources()
	trace("enemy selected")
	check(scene.source_picker.item_count == 33, "editor exposes all30 authored enemies and3 bosses")
	check(scene.entry_picker.item_count > 2 and scene.grid.get_child_count() == 63, "editor exposes integer9x7 grid and real entries")
	scene._apply_edit()
	check(scene.service.validate_import(scene.snapshots[1]).ok, "actual apply control retains valid layout")
	var expected = scene.snapshots[1].duplicate(true)
	scene.file_action = "snapshot"; scene._file_selected("res://tools_ui_snapshot.json")
	check(json_equal(JSON.parse_string(FileAccess.get_file_as_string("res://tools_ui_snapshot.json")), expected), "actual export preserves every snapshot field and numeric value")
	scene.snapshots[1] = {}; scene.file_action = "import"; scene._file_selected("res://tools_ui_snapshot.json")
	check(json_equal(scene.snapshots[1], expected), "actual import restores every snapshot field and numeric value")
	check(CombatEngine.new(scene.db).simulate(scene.snapshots[0], scene.snapshots[1], 9773).replay_digest == CombatEngine.new(scene.db).simulate(scene.snapshots[0], expected, 9773).replay_digest, "JSON roundtrip preserves exact seeded combat digest")
	scene.file_action = "enemy"; scene._file_selected("res://tools_ui_enemy.json")
	check(JSON.parse_string(FileAccess.get_file_as_string("res://tools_ui_enemy.json")).format == "backpack-pve-enemy-draft", "actual enemy draft export contains layout")
	scene.file_action = "resource"; scene._file_selected("res://tools_ui_enemy.tres")
	trace("resource exported")
	check(load("res://tools_ui_enemy.tres") is EnemyBuildDefinition, "actual Resource export reloads as EnemyBuildDefinition")
	var tabs = scene.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 1
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://tools_editor.png")
	scene.count_input.value = 2; scene.seed_input.value = 67731
	await scene._run_batch()
	trace("batch completed")
	check(scene.last_report.get("count", 0) == 2 and scene.last_report.get("ok", false), "actual simulator control runs configured seed range")
	scene.file_action = "report"; scene._file_selected("res://tools_ui_batch.json")
	check(json_equal(JSON.parse_string(FileAccess.get_file_as_string("res://tools_ui_batch.json")), scene.last_report), "actual report export preserves all seed results and summary fields")
	tabs.current_tab = 2
	await process_frame; await process_frame
	check(scene.seed_input.get_parent().size.y <= 64 and scene.seed_input.size.x >= 100, "batch controls remain one readable horizontal row")
	check(scene.snapshot_texts[0].size.y >= 200 and scene.output.size.y >= 150, "batch snapshot and report editors retain usable viewport space")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://tools_simulator.png")
	var report = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "renderer": DisplayServer.get_name(), "no_game_autoload": not root.has_node("Game")}
	var file = FileAccess.open("res://tools_ui_test_results.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "\t")); file.close()
	print("TOOLS_UI_TESTS ", JSON.stringify(report))
	scene.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
