extends Node
var output: String = ""
var baseline_gold: int
var original_uids: Array = []
var moved_uid: String = ""
var observed = {"bag_grid_visible_while_dragged": false, "bag_grid_hides_after_drop": false, "entered_storage": false, "sold_from_new_scroll": false, "undo_restored": false, "redo_sold": false, "settings_opened": false}
var clock: float = 0.0
var started: int = 0
var ready_for_input: bool = false
var stopping: bool = false
func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("prepare")
func prepare():
	while not Expedition.initialized: await get_tree().process_frame
	Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 1337, true)
	Expedition.flow.skip_tutorial(); Expedition.flow.choose_route(0)
	await get_tree().create_timer(5.5).timeout
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())
	baseline_gold = int(Expedition.flow.run.gold)
	for item in Expedition.flow.run.build.items: original_uids.append(str(item.uid))
	DisplayServer.window_set_title("New Art Pointer QA - isolated saves")
	ready_for_input = true; started = Time.get_ticks_msec()
func _process(delta):
	if not ready_for_input or stopping: return
	clock += delta
	if clock < 0.15: return
	clock = 0.0
	var build: Dictionary = Expedition.flow.run.build
	var board = Game.PLAYER.INVENTORY.get_node("SuppliedGrid")
	var dragging_bag = is_instance_valid(Game.draggedItem) and Game.draggedItem.isBag()
	if dragging_bag and board.showing_empty: observed.bag_grid_visible_while_dragged = true
	if observed.bag_grid_visible_while_dragged and not dragging_bag and not board.showing_empty: observed.bag_grid_hides_after_drop = true
	for entry in build.storage:
		if str(entry.uid) in original_uids:
			moved_uid = str(entry.uid); observed.entered_storage = true
	var found = Expedition.flow.placement.find(build, moved_uid) if not moved_uid.is_empty() else {}
	if observed.entered_storage and found.is_empty() and int(Expedition.flow.run.gold) > baseline_gold:
		if observed.undo_restored: observed.redo_sold = true
		else: observed.sold_from_new_scroll = true
	if observed.sold_from_new_scroll and not found.is_empty(): observed.undo_restored = true
	if Expedition.panel.visible and Expedition.current_page == "SETTINGS": observed.settings_opened = true
	var file = FileAccess.open(output.path_join("pointer-state.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ready": true, "checks": observed, "all_passed": not observed.values().has(false), "gold": Expedition.flow.run.gold, "storage": build.storage.size(), "items": build.items.size(), "current_page": Expedition.current_page, "mouse": str(Util.getMousePosInWindow()), "sale_rect": str(Game.SELLBOX.rect)}, "\t")); file.close()
	if FileAccess.file_exists(output.path_join("stop.txt")) or Time.get_ticks_msec() - started > 240000: finish()
func finish():
	stopping = true
	Game._begin_shutdown(); await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit")
