extends Control

var db
var service
var snapshots: Array = [{}, {}]
var side_picker: OptionButton
var source_picker: OptionButton
var difficulty_picker: OptionButton
var entry_picker: OptionButton
var x_input: SpinBox
var y_input: SpinBox
var rotation_picker: OptionButton
var grid: GridContainer
var details: TextEdit
var snapshot_texts: Array = []
var message: Label
var seed_input: SpinBox
var count_input: SpinBox
var output: TextEdit
var last_report: Dictionary = {}
var dialog: FileDialog
var file_action: String = ""
var running: bool = false

func _ready():
	db = ContentDB.new()
	service = PvEDeveloperToolService.new(db)
	var face = load("res://Assets/Fonts/Localized/NotoSansSC-Regular_.otf")
	if face is Font:
		theme = Theme.new(); theme.default_font = face
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(margin)
	for name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: margin.add_theme_constant_override(name, 14)
	var layout = VBoxContainer.new(); margin.add_child(layout)
	_label("PvE 开发工具 / Developer Tools — 与正常游戏和存档隔离", layout)
	message = _label("", layout)
	var tabs = TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; layout.add_child(tabs)
	_inspector_tab(tabs)
	_editor_tab(tabs)
	_simulator_tab(tabs)
	dialog = FileDialog.new(); dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.use_native_dialog = false; dialog.size = Vector2i(1000, 650); add_child(dialog)
	dialog.file_selected.connect(_file_selected)
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	snapshots[1] = service.opponent_snapshot(str(db.rows("enemy_builds")[0].id))
	_select_source()
	_status("仅编辑内存草稿；导出不会覆盖事实源CSV。 Source CSVs are read-only.")

func _label(text: String, parent: Node) -> Label:
	var label = Label.new(); label.text = text
	# Labels in a horizontal control row must keep their natural width;
	# wrapping them to zero minimum width stretches the whole row vertically.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label); return label

func _button(text: String, callback: Callable, parent: Node) -> Button:
	var button = Button.new(); button.text = text; button.pressed.connect(callback); parent.add_child(button); return button

func _box(name: String, parent: Node) -> VBoxContainer:
	var box = VBoxContainer.new(); box.name = name; parent.add_child(box); return box

func _spin(parent: Node, maximum: float, value: float = 0) -> SpinBox:
	var spin = SpinBox.new(); spin.min_value = 0; spin.max_value = maximum; spin.step = 1; spin.value = value; parent.add_child(spin); return spin

func _text(parent: Node, readonly: bool = true) -> TextEdit:
	var text = TextEdit.new(); text.editable = not readonly; text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; text.size_flags_vertical = Control.SIZE_EXPAND_FILL; text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; parent.add_child(text); return text

func _status(value): message.text = str(value)

func _inspector_tab(tabs: TabContainer):
	var box = _box("定义检查 Inspector", tabs)
	var picker = OptionButton.new(); box.add_child(picker)
	for row in db.rows("items") + db.rows("bags"):
		picker.add_item(str(row.id) + " · " + db.text(row.name_key)); picker.set_item_metadata(picker.item_count - 1, row.id)
	var text = _text(box)
	var inspect = func(_index = 0): text.text = JSON.stringify(service.inspect_definition(str(picker.get_selected_metadata())), "\t", true)
	picker.item_selected.connect(inspect)
	_button("检查全部内容 / Validate all content", func():
		var result = ContentValidator.new(db).validate(); text.text = JSON.stringify(result, "\t", true); _status("PASS" if result.ok else result.error), box)
	inspect.call()

func _editor_tab(tabs: TabContainer):
	var box = _box("构筑编辑 Build Editor", tabs)
	var top = HBoxContainer.new(); box.add_child(top)
	side_picker = OptionButton.new(); side_picker.add_item("玩家 Player"); side_picker.add_item("敌人 Enemy"); top.add_child(side_picker)
	side_picker.item_selected.connect(func(_i): _populate_sources())
	source_picker = OptionButton.new(); source_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(source_picker)
	source_picker.item_selected.connect(func(_i): _select_source())
	difficulty_picker = OptionButton.new(); top.add_child(difficulty_picker)
	for row in db.rows("difficulty_levels"):
		difficulty_picker.add_item(db.text(row.name_key)); difficulty_picker.set_item_metadata(difficulty_picker.item_count - 1, row.id)
	difficulty_picker.select(1); difficulty_picker.item_selected.connect(func(_i): _select_source())
	var exports = HBoxContainer.new(); box.add_child(exports)
	_button("导入快照 Import", func(): _open_file("import"), exports)
	_button("导出快照 Export", func(): _open_file("snapshot"), exports)
	_button("导出敌人草稿 Draft JSON", func(): _open_file("enemy"), exports)
	_button("导出 EnemyBuildDefinition", func(): _open_file("resource"), exports)
	var edit = HBoxContainer.new(); box.add_child(edit)
	entry_picker = OptionButton.new(); entry_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; edit.add_child(entry_picker); entry_picker.item_selected.connect(func(_i): _entry_selected())
	_label("X", edit); x_input = _spin(edit, 8); _label("Y", edit); y_input = _spin(edit, 6)
	rotation_picker = OptionButton.new(); edit.add_child(rotation_picker)
	for value in [0, 90, 180, 270]: rotation_picker.add_item(str(value)); rotation_picker.set_item_metadata(rotation_picker.item_count - 1, value)
	_button("应用坐标 Apply", _apply_edit, edit)
	_label("选择物品后可点击网格指定左上角，再点击应用；所有移动复用 PlacementService 校验。格内列出背包与物品UID。", box)
	var body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(body)
	grid = GridContainer.new(); grid.columns = 9; body.add_child(grid)
	for y in 7:
		for x in 9:
			var button = _button("", func(): x_input.value = x; y_input.value = y, grid)
			button.custom_minimum_size = Vector2(66, 66); button.clip_text = true
	details = _text(body)
	_populate_sources()

func _populate_sources():
	source_picker.clear()
	for row in db.rows("character_loadouts") if side_picker.selected == 0 else db.rows("enemy_builds") + db.rows("bosses"):
		var key = str(row.get("name_key", ""))
		source_picker.add_item(str(row.id) + " · " + db.text(key)); source_picker.set_item_metadata(source_picker.item_count - 1, row.id)
	_select_source()

func _select_source():
	if source_picker == null or source_picker.item_count == 0: return
	var id = str(source_picker.get_selected_metadata())
	var snapshot = service.loadout_snapshot(id) if side_picker.selected == 0 else service.opponent_snapshot(id, str(difficulty_picker.get_selected_metadata()))
	if not snapshot.get("ok", false): _status(snapshot.get("error", "error")); return
	snapshots[side_picker.selected] = snapshot
	_refresh_editor()

func _refresh_editor():
	if entry_picker == null: return
	var snapshot: Dictionary = snapshots[side_picker.selected]
	entry_picker.clear()
	for field in ["items", "bags"]:
		for item in snapshot.get(field, []):
			entry_picker.add_item(str(item.instance_id) + " · " + str(item.def_id)); entry_picker.set_item_metadata(entry_picker.item_count - 1, str(item.instance_id))
	var build = service.build_from_snapshot(snapshot)
	for y in 7:
		for x in 9:
			var occupants: Array = []; var tooltip: Array = ["(%d,%d)" % [x, y]]
			for field in ["bags", "items"]:
				for entry in build[field]:
					if Vector2i(x, y) in service.placement.cells(entry):
						occupants.append(("B:" if field == "bags" else "I:") + str(entry.uid)); tooltip.append(str(entry.definition_id))
			var cell: Button = grid.get_child(y * 9 + x)
			cell.text = "%d,%d\n%s" % [x, y, "\n".join(occupants)]; cell.tooltip_text = "\n".join(tooltip + occupants)
	details.text = JSON.stringify({"validation": service.validate_import(snapshot), "base_stats": snapshot.get("base_stats", {}), "boss_phases": snapshot.get("boss_phases", []), "encounter_modifiers": snapshot.get("encounter_modifiers", [])}, "\t", true)
	_entry_selected()
	_sync_snapshot_texts()

func _entry_selected():
	if entry_picker.item_count == 0: return
	var found = service.placement.find(service.build_from_snapshot(snapshots[side_picker.selected]), str(entry_picker.get_selected_metadata()))
	if not found.get("ok", false): return
	x_input.value = int(found.entry.x); y_input.value = int(found.entry.y); rotation_picker.select(int(found.entry.rotation) / 90)

func _apply_edit():
	if entry_picker.item_count == 0: return
	var result = service.edit_snapshot(snapshots[side_picker.selected], str(entry_picker.get_selected_metadata()), int(x_input.value), int(y_input.value), int(rotation_picker.get_selected_metadata()))
	if not result.ok: _status(result.get("message", result.error)); return
	snapshots[side_picker.selected] = result.snapshot
	_refresh_editor(); _status("布局合法，草稿已更新。 Valid draft updated.")

func _simulator_tab(tabs: TabContainer):
	var box = _box("快照重放与批量模拟 Replay & Batch", tabs)
	var row = HBoxContainer.new(); box.add_child(row)
	_label("首个种子 First seed", row); seed_input = _spin(row, 2147483646, 1)
	seed_input.custom_minimum_size.x = 140
	_label("场次 Count (1–2000)", row); count_input = _spin(row, 2000, 20); count_input.min_value = 1
	count_input.custom_minimum_size.x = 100
	_button("运行批量 Run batch", _run_batch, row)
	_button("导出报告 Export report", func(): _open_file("report"), row)
	_label("左为玩家、右为敌人。可粘贴或从编辑器导入完整JSON；相同快照与种子应得到相同 replay_digest。", box)
	var source = HBoxContainer.new(); source.custom_minimum_size.y = 220; source.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(source)
	snapshot_texts = [_text(source, false), _text(source, false)]
	output = _text(box)

func _sync_snapshot_texts():
	if snapshot_texts.size() != 2: return
	for index in 2: snapshot_texts[index].text = JSON.stringify(snapshots[index], "\t", true)

func _run_batch():
	if running: return
	var pair: Array = []
	for index in 2:
		var parsed = JSON.parse_string(snapshot_texts[index].text)
		var valid = service.validate_import(parsed)
		if not valid.ok: _status("Side %d: %s" % [index, valid.error]); return
		pair.append(valid.snapshot)
	running = true
	var runs: Array = []
	for index in int(count_input.value):
		var one = service.batch(pair[0], pair[1], int(seed_input.value) + index, 1)
		if not one.ok: _status(one.error); running = false; return
		runs.append(one.runs[0])
		if index % 5 == 0: _status("模拟 %d/%d" % [index + 1, int(count_input.value)]); await get_tree().process_frame
	last_report = service.batch_summary(runs)
	output.text = JSON.stringify(last_report, "\t", true)
	_status("完成 %d 场，玩家胜率 %.1f%%。" % [runs.size(), float(last_report.win_rate) * 100.0]); running = false

func _open_file(action: String):
	file_action = action
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "import" else FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.tres ; EnemyBuildDefinition"]) if action == "resource" else PackedStringArray(["*.json ; JSON"])
	dialog.current_file = "enemy_definition.tres" if action == "resource" else "batch_report.json" if action == "report" else "enemy_draft.json" if action == "enemy" else "snapshot.json"
	dialog.popup_centered()

func _file_selected(path: String):
	if file_action == "import":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		var result = service.validate_import(parsed)
		if not result.ok: _status(result.error); return
		snapshots[side_picker.selected] = result.snapshot; _refresh_editor(); _status("快照已导入。 Snapshot imported."); return
	var value: Dictionary = snapshots[side_picker.selected]
	if file_action in ["enemy", "resource"]:
		value = service.export_enemy(value)
		if not value.ok: _status(value.error); return
	elif file_action == "report": value = last_report
	if value.is_empty(): _status("没有可导出的数据。 No data to export."); return
	if file_action == "resource":
		var error = ResourceSaver.save(EnemyBuildDefinition.new(value.definition), path)
		_status("ResourceSaver: " + error_string(error)); return
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: _status(error_string(FileAccess.get_open_error())); return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n"); file.close(); _status("已导出 / Exported: " + path)
