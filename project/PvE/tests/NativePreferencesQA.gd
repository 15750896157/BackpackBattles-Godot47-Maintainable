extends Node

var output = ""
var stage = "write"
var checks = 0
var failures: Array = []
var evidence: Dictionary = {}
var preferences

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
		if argument.begins_with("--preferences-stage="): stage = argument.trim_prefix("--preferences-stage=")
	call_deferred("run_tests")

func frames(count = 4):
	for index in range(count): await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func wait_for(predicate: Callable, seconds = 6.0):
	var deadline = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	return predicate.call()

func check(condition, message):
	checks += 1
	if not condition: failures.append(message)

func save_json(path: String, value):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  ")); file.close()

func snapshot(name: String):
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(stage + "-" + name + ".png"))

func bindings(action: String) -> Array:
	var result: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append({"type": "key", "code": int(event.physical_keycode if event.physical_keycode else event.keycode), "ctrl": event.ctrl_pressed, "shift": event.shift_pressed, "alt": event.alt_pressed})
		elif event is InputEventJoypadButton: result.append({"type": "joy", "button": int(event.button_index)})
		elif event is InputEventJoypadMotion: result.append({"type": "axis", "axis": int(event.axis), "value": int(signf(event.axis_value))})
		elif event is InputEventMouseButton: result.append({"type": "mouse", "button": int(event.button_index)})
	return result

func bindings_equal(first: Array, second: Array) -> bool:
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))

func options() -> Array:
	return Expedition.popup_content.find_children("*", "Button", true, false).filter(func(node):return node.has_meta("setting_key"))

func choose_option(index: int, selected: int):
	var control = options()[index]
	var key=str(control.get_meta("setting_key"))
	var target=control.get_meta("setting_values")[selected]
	for attempt in 8:
		if preferences.values[key]==target:return
		control=options().filter(func(node):return node.get_meta("setting_key")==key)[0]
		control.pressed.emit()
		await frames(3)

func begin_capture(action: String):
	# Hidden legacy input compatibility is exercised with a QA-only button.
	# The production settings page intentionally exposes no keyboard editor.
	preferences.show_page()
	await frames(3)
	var control=Button.new();control.text="QA legacy binding fixture";Expedition.popup_content.add_child(control)
	control.pressed.connect(func():preferences.capture_action=action;preferences.capture_button=control)
	control.pressed.emit()
	check(preferences.capture_action==action,"legacy capture fixture begins: "+action)

func capture_key(action: String, keycode: int):
	await begin_capture(action)
	var event = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.ctrl_pressed = true
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	check(preferences.capture_action == "", "native key input completes capture: " + action)
	event.pressed = false
	Input.parse_input_event(event)

func key_event(keycode: int, ctrl = false, shift = false) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.pressed = true
	return event

func joy_event(button: int) -> InputEventJoypadButton:
	var event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

func all_bindings() -> Dictionary:
	var result = {}
	for action in preferences.defaults: result[action] = bindings(action)
	return result

func settings_bytes() -> String:
	return FileAccess.get_file_as_string(Expedition.flow.saves.base_path.path_join("settings.save"))

func reject_capture(action: String, event: InputEvent, conflict: String):
	await begin_capture(action)
	var before_bindings = all_bindings()
	var before_values = preferences.values.duplicate(true)
	var before_file = settings_bytes()
	Input.parse_input_event(event)
	await frames(3)
	check(preferences.capture_action.is_empty() and preferences.capture_button == null, "conflict ends capture safely: " + action)
	check(all_bindings() == before_bindings, "conflict preserves every old runtime binding: " + action)
	check(preferences.values == before_values and settings_bytes() == before_file, "conflict does not mutate preferences or write settings: " + action)
	check(Expedition.t("native.key_" + conflict) in Expedition.toast.text, "conflict identifies localized action: " + conflict)
	if not evidence.has("conflict_captures"): evidence.conflict_captures = []
	evidence.conflict_captures.append({"driver": "QA-only legacy capture Button.pressed -> Input.parse_input_event", "action": action, "event": event.as_text(), "conflict": conflict, "feedback": Expedition.toast.text, "bindings_before_sha256": JSON.stringify(before_bindings, "", true).sha256_text(), "bindings_after_sha256": JSON.stringify(all_bindings(), "", true).sha256_text(), "settings_before_sha256": before_file.sha256_text(), "settings_after_sha256": settings_bytes().sha256_text(), "values_unchanged": preferences.values == before_values})
	if event is InputEventKey or event is InputEventJoypadButton:
		event.pressed = false
		Input.parse_input_event(event)

func accept_capture(action: String, event: InputEvent):
	await begin_capture(action)
	Input.parse_input_event(event)
	await frames(3)
	check(preferences.capture_action.is_empty() and Expedition.toast_time <= 0.0, "cross-context input is accepted: " + action)
	if not evidence.has("accepted_captures"): evidence.accepted_captures = []
	evidence.accepted_captures.append({"driver": "native binding row Button.pressed -> Input.parse_input_event", "action": action, "event": event.as_text(), "bindings": bindings(action), "capture_finished": preferences.capture_action.is_empty()})
	if event is InputEventKey or event is InputEventJoypadButton:
		event.pressed = false
		Input.parse_input_event(event)

func check_conflicts_and_cancel():
	await reject_capture("combat_speed_down", key_event(KEY_RIGHT), "combat_speed_up")
	check("previous binding" in Expedition.toast.text, "English rejection explains that the previous binding was kept")
	await snapshot("08-english-battle-binding-conflict")
	TranslationServer.set_locale("zh_Hans_CN")
	await reject_capture("combat_speed_down", key_event(KEY_RIGHT, true), "combat_speed_up")
	check("已保留原绑定" in Expedition.toast.text, "Chinese rejection explains that the previous binding was kept")
	await snapshot("09-chinese-modifier-binding-conflict")
	TranslationServer.set_locale("en")
	await reject_capture("combat_play", key_event(KEY_SPACE), "combat_pause")
	await reject_capture("combat_pause", joy_event(JOY_BUTTON_DPAD_UP), "combat_play")
	await reject_capture("combat_speed_down", joy_event(JOY_BUTTON_RIGHT_SHOULDER), "combat_speed_up")
	await reject_capture("ui_focus_prev", key_event(KEY_TAB), "ui_focus_next")
	await accept_capture("ui_focus_prev", key_event(KEY_TAB, false, true))
	check(bindings("ui_focus_prev").any(func(row): return row.type == "key" and int(row.code) == KEY_TAB and row.shift), "default Shift+Tab/Tab pair remains valid")
	await accept_capture("start_battle", key_event(KEY_SPACE))
	check(bindings("start_battle").any(func(row): return row.type == "key" and int(row.code) == KEY_SPACE), "keyboard Space can be reused in shop and combat")
	await accept_capture("ui_left", key_event(KEY_LEFT))
	check(bindings("ui_left").any(func(row): return row.type == "key" and int(row.code) == KEY_LEFT), "keyboard Left can navigate inventory and slow combat in separate contexts")
	await accept_capture("combat_pause", joy_event(JOY_BUTTON_A))
	check(bindings("combat_pause").any(func(row): return row.type == "joy" and int(row.button) == JOY_BUTTON_A), "joy A can be reused for inventory accept and combat pause")
	await accept_capture("combat_speed_down", joy_event(JOY_BUTTON_DPAD_LEFT))
	check(bindings("combat_speed_down").any(func(row): return row.type == "joy" and int(row.button) == JOY_BUTTON_DPAD_LEFT), "joy Left can navigate inventory and slow combat in separate contexts")
	for close_method in ["back", "close_popup"]:
		await begin_capture("combat_play")
		var before_bindings = all_bindings()
		var before_file = settings_bytes()
		if close_method == "back":
			var back = Expedition.menu_header.get_node("CloseMenu")
			back.pressed.emit()
		else: Expedition.close_popup()
		await frames(3)
		check(preferences.capture_action.is_empty() and preferences.capture_button == null, "leaving binding page cancels pending capture: " + close_method)
		var stray = key_event(KEY_F8)
		Input.parse_input_event(stray)
		await frames(3)
		check(all_bindings() == before_bindings and settings_bytes() == before_file, "next key after leaving cannot silently rebind: " + close_method)
		if not evidence.has("cancelled_captures"): evidence.cancelled_captures = []
		evidence.cancelled_captures.append({"exit": close_method, "driver": "native Back Button.pressed" if close_method == "back" else "NativeExpedition.close_popup", "subsequent_event": stray.as_text(), "capture_action": preferences.capture_action, "capture_button_is_null": preferences.capture_button == null, "bindings_before_sha256": JSON.stringify(before_bindings, "", true).sha256_text(), "bindings_after_sha256": JSON.stringify(all_bindings(), "", true).sha256_text(), "settings_before_sha256": before_file.sha256_text(), "settings_after_sha256": settings_bytes().sha256_text()})
		stray.pressed = false
		Input.parse_input_event(stray)
	preferences.show_inputs()

func capture_controller(action: String, axis: int = -1):
	await begin_capture(action)
	var event: InputEvent
	if axis < 0:
		event = InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_LEFT_STICK
		event.pressed = true
	else:
		event = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = -0.95
	Input.parse_input_event(event)
	await frames(3)
	check(preferences.capture_action == "", "native joy input completes capture: " + action)
	if axis < 0: event.pressed = false
	else: event.axis_value = 0.0
	Input.parse_input_event(event)

func check_volumes(expected: Dictionary):
	for pair in [["music", "BGM"], ["ambient", "PvEAmbient"], ["ui", "PvEUI"], ["combat", "PvECombat"]]:
		var index = AudioServer.get_bus_index(pair[1])
		if not evidence.has("volumes"): evidence.volumes = []
		evidence.volumes.append({"bus": pair[1], "expected": float(expected[pair[0]]), "actual": db_to_linear(AudioServer.get_bus_volume_db(index)), "legacy_initializing": Settings.initializing})
		check(index >= 0, "audio bus exists: " + pair[1])
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(index)), float(expected[pair[0]])), "audio bus applies saved linear volume: " + pair[0])
	check(Sound.itemMovePlayer.bus == &"PvEUI", "actual native item movement player follows UI bus")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == &"PvEUI", "legacy SFX routes through UI volume")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == &"PvECombat", "native voice routes through combat volume")

func run_write():
	var initial_defaults = preferences.values.duplicate(true)
	var default_actions = {}
	for action in preferences.defaults: default_actions[action] = bindings(action)
	preferences.show_page()
	await frames()
	await choose_option(0, 1)
	await choose_option(1, 2)
	await choose_option(2, 1)
	check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS), "actual window selection enables borderless mode")
	await choose_option(3, 2)
	check(DisplayServer.window_get_size() == Vector2i(1600, 900), "actual resolution selection resizes native window")
	var checks_ui = Expedition.popup_content.find_children("*", "CheckBox", true, false)
	for control in checks_ui: control.button_pressed = true
	Expedition.menus.settings.show_page("sound");await frames()
	var levels = [0.19, 0.31, 0.43, 0.57]
	var sliders = Expedition.popup_content.find_children("*", "HSlider", true, false)
	check(sliders.size() == 4, "settings renders all four category volume controls")
	for index in range(sliders.size()): sliders[index].value = levels[index] * 100
	await frames()
	check_volumes(preferences.values)
	check(Expedition.ui_theme.default_font_size == 29 and TranslationServer.get_locale().begins_with("en"), "native language and scale selections apply")
	await snapshot("01-settings-controls")
	var suffix_before = bindings("rotate_left_button_controller")
	await capture_key("rotate_left_button", KEY_K)
	check(bindings_equal(bindings("rotate_left_button_controller"), suffix_before), "keyboard rebind preserves controller suffix defaults")
	await capture_controller("rotate_left_button")
	check(bindings("rotate_left_button").any(func(row): return row.type == "key" and int(row.code) == KEY_K and row.ctrl), "controller button rebind preserves new keyboard binding")
	check(bindings("rotate_left_button_controller").any(func(row): return row.type == "joy" and int(row.button) == JOY_BUTTON_LEFT_STICK), "controller capture targets suffix action")
	await capture_controller("rotate_left_button", JOY_AXIS_RIGHT_X)
	check(bindings("rotate_left_button_controller").any(func(row): return row.type == "axis" and int(row.axis) == JOY_AXIS_RIGHT_X and int(row.value) == -1), "axis rebind preserves axis identity and sign on controller suffix")
	var up_controller = bindings("ui_up").filter(func(row): return row.type != "key")
	await capture_key("ui_up", KEY_I)
	check(bindings_equal(bindings("ui_up").filter(func(row): return row.type != "key"), up_controller), "mixed action keyboard rebind preserves its controller event")
	await capture_controller("ui_up", JOY_AXIS_LEFT_Y)
	check(bindings("ui_up").any(func(row): return row.type == "key" and int(row.code) == KEY_I and row.ctrl), "mixed action axis rebind preserves keyboard event")
	check(bindings("ui_up").any(func(row): return row.type == "axis" and int(row.axis) == JOY_AXIS_LEFT_Y and int(row.value) == -1), "mixed action receives selected axis")
	await snapshot("02-keyboard-controller-axis-bindings")
	await check_conflicts_and_cancel()
	var expected_actions = {}
	for action in preferences.values.inputs: expected_actions[action] = bindings(action)
	var saved = Expedition.flow.saves.load_save("settings")
	check(saved.ok and not saved.recovered, "actual settings file saves and verifies without backup recovery")
	save_json(output.path_join("expected-settings.json"), {"settings": preferences.values.duplicate(true), "bindings": expected_actions, "defaults": initial_defaults, "default_bindings": default_actions})
	var loaded = load("res://PvE/NativePreferences.gd").new(Expedition)
	check(is_equal_approx(float(loaded.values.ui_scale), 1.2) and loaded.values.inputs.has("rotate_left_button_controller"), "new preferences instance reads written scale and controller suffix")
	await check_rest_audio()

func check_rest_audio():
	Expedition.close_popup()
	check(Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 61015, true).ok, "REST display fixture starts from a valid generated run")
	await frames()
	Expedition.flow.run.current_node = {"type": "rest", "id": "qa_rest_audio", "name_key": "ui.rest"}
	Expedition.flow._transition("REST")
	Expedition.show_event()
	check(await wait_for(func(): return Sound.bgmPlayer1.stream == Sound.postFightBGM_survival and Sound.bgmPlayer1.playing and Sound.bgmPlayer1.bus == &"PvEAmbient"), "REST actually plays original Ambient 6 through ambient bus")
	check(not Sound.bgmPlayer2.playing, "REST has no second overlapping music player")
	evidence.rest_stream = Sound.bgmPlayer1.stream.resource_path
	evidence.rest_bus = str(Sound.bgmPlayer1.bus)
	await snapshot("03-rest-original-ambient")
	Expedition.flow._transition("ROUTE_SELECT")
	Expedition.show_routes()
	check(await wait_for(func(): return Sound.bgmPlayer1.stream == Sound.shopBGM and Sound.bgmPlayer1.playing and Sound.bgmPlayer1.bus == &"BGM"), "route returns original shop music to music bus")
	check(not Sound.bgmPlayer2.playing, "route return has no second overlapping music player")
	evidence.route_stream = Sound.bgmPlayer1.stream.resource_path
	evidence.route_bus = str(Sound.bgmPlayer1.bus)
	await snapshot("04-route-original-shop-music")
	evidence.rest_fixture = "Valid generated run; REST/current_node are explicit rendering/audio fixtures, not proof of campaign progression."

func run_reopen():
	var expected = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected-settings.json")))
	for key in expected.settings:
		if key == "inputs": continue
		if expected.settings[key] is float:
			check(is_equal_approx(float(preferences.values[key]), float(expected.settings[key])), "fresh process restores saved setting: " + key)
		else: check(preferences.values[key] == expected.settings[key], "fresh process restores saved setting: " + key)
	evidence.loaded_bindings = {}
	for action in expected.bindings:
		evidence.loaded_bindings[action] = bindings(action)
		check(bindings_equal(bindings(action), expected.bindings[action]), "fresh process applies saved keyboard/joy/axis: " + action)
	check_volumes(expected.settings)
	preferences.show_page()
	await snapshot("05-fresh-process-settings")
	preferences.show_inputs()
	await snapshot("06-fresh-process-bindings")
	for action in preferences.defaults:
		InputMap.action_erase_events(action)
		for event in preferences.defaults[action]:InputMap.action_add_event(action,event)
	preferences.values.inputs={};preferences.save()
	await frames()
	for action in expected.default_bindings: check(bindings_equal(bindings(action), expected.default_bindings[action]), "legacy default compatibility restores original action: " + action)
	preferences.values = expected.defaults.duplicate(true)
	preferences.apply()
	preferences.save()
	check_volumes(preferences.values)
	var saved = Expedition.flow.saves.load_save("settings")
	check(saved.ok and saved.data.inputs.is_empty() and is_equal_approx(float(saved.data.ui_scale), 1.0), "QA settings finish with original defaults persisted")
	preferences.show_page()
	await snapshot("07-defaults-restored")
	evidence.default_settings_restored = true

func run_tests():
	DirAccess.make_dir_recursive_absolute(output)
	check(await wait_for(func(): return Expedition.initialized, 90), "real native Main initializes")
	preferences = Expedition.preferences
	await frames()
	if stage == "write": await run_write()
	else: await run_reopen()
	Expedition.close_popup()
	save_json(output.path_join(stage + "-report.json"), {"stage": stage, "checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "entry": "res://Core/Main.tscn", "save_path": Expedition.flow.saves.base_path, "evidence": evidence})
	print("NATIVE_PREFERENCES_QA " + JSON.stringify({"stage": stage, "checks": checks, "failures": failures}))
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
