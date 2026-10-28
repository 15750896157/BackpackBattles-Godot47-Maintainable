extends RefCounted

const REBINDABLE = ["rotate_left_button", "rotate_right_button", "reserve", "reroll", "start_battle", "combat_pause", "combat_play", "combat_speed_up", "combat_speed_down", "undo", "redo", "ui_focus_next", "ui_focus_prev", "push_to_storage", "show_hints", "ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down", "pve_next_region", "pve_prev_region"]
const INPUT_CONTEXTS = [
	["combat_pause", "combat_play", "combat_speed_up", "combat_speed_down"],
	["rotate_left_button", "rotate_right_button", "reserve", "reroll", "start_battle", "undo", "redo", "ui_focus_next", "ui_focus_prev", "push_to_storage", "show_hints", "ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down", "pve_next_region", "pve_prev_region", "move_cursor_left", "move_cursor_right", "move_cursor_up", "move_cursor_down"]
]
var owner
var values: Dictionary = {"ui_scale": 1.0, "language": "zh_CN", "window_mode": "windowed", "resolution": "1280x720", "music": 0.3, "ambient": 0.3, "ui": 0.7, "combat": 0.6, "reduce_flash": false, "reduce_motion": false, "reduce_effects": false, "high_contrast": false, "inputs": {}}
var capture_action: String = ""
var capture_button: Button
var defaults: Dictionary = {}

func _init(expedition):
	owner = expedition
	var saved = owner.flow.saves.load_save("settings")
	if saved.ok:
		for key in values:
			if saved.data.has(key) and typeof(saved.data[key]) == typeof(values[key]): values[key] = saved.data[key]
	values.ui_scale = clampf(float(values.ui_scale), 0.8, 1.4)
	for action in REBINDABLE:
		defaults[action] = InputMap.action_get_events(action).duplicate()
		if InputMap.has_action(action + "_controller"): defaults[action + "_controller"] = InputMap.action_get_events(action + "_controller").duplicate()

func apply():
	for name in ["PvEUI", "PvECombat", "PvEAmbient"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, name)
			AudioServer.set_bus_send(index, "Master")
	for pair in [["BGM", "music"], ["PvEUI", "ui"], ["PvECombat", "combat"], ["PvEAmbient", "ambient"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]), linear_to_db(clampf(float(values[pair[1]]), 0.0, 1.0)))
	Sound.itemMovePlayer.bus = &"PvEUI"
	AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "PvEUI")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Voice"), "PvECombat")
	Settings.setVal(Settings.Setting.language, "zh_Hans_CN" if str(values.language).begins_with("zh") else "en")
	for action in values.inputs:
		if action not in defaults or not values.inputs[action] is Dictionary: continue
		var saved: Dictionary = values.inputs[action]
		if saved.has("keyboard") or saved.has("controller"):
			for device in ["keyboard", "controller"]:
				if saved.get(device) is Dictionary: apply_binding(action, saved[device])
		else:
			apply_binding(action, saved)
	owner.ui_theme.default_font_size = roundi(24 * values.ui_scale)
	# Command-line resolutions are kept usable for the actual-window QA suite.
	var arguments = OS.get_cmdline_args()
	if "--resolution" not in arguments:
		apply_window()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var index = arguments.find("--resolution")
		if index + 1 < arguments.size():
			var dimensions = arguments[index + 1].split("x")
			if dimensions.size() == 2: DisplayServer.window_set_size(Vector2i(int(dimensions[0]), int(dimensions[1])))

func apply_window():
	var mode = str(values.window_mode)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if mode == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode == "borderless")
	if mode != "fullscreen":
		var dimensions = str(values.resolution).split("x")
		if dimensions.size() == 2:
			var desired = Vector2i(int(dimensions[0]), int(dimensions[1]))
			DisplayServer.window_set_size(desired)
			DisplayServer.window_set_position(DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() - desired) / 2)

func save():
	if not owner.flow.saves.save("settings", values): owner.notice("save_write_failed")

func show_page():
	owner.menus.settings.show_page()

func show_inputs():
	owner.menus.settings.show_page("inputs")

func cancel_capture():
	capture_action = ""
	capture_button = null

func canonical_action(action: String) -> String:
	var base = action.trim_suffix("_controller")
	return str({"move_cursor_left": "ui_left", "move_cursor_right": "ui_right", "move_cursor_up": "ui_up", "move_cursor_down": "ui_down"}.get(base, base))

func conflicting_action(action: String, event: InputEvent) -> String:
	var base = canonical_action(action)
	for context in INPUT_CONTEXTS:
		if base not in context: continue
		for other in context:
			var other_base = canonical_action(other)
			if other_base == base: continue
			for candidate in [other, other + "_controller"]:
				if not InputMap.has_action(candidate): continue
				for previous in InputMap.action_get_events(candidate):
					# Native combat/shop handlers ignore additional key modifiers. The
					# previous/next focus pair explicitly distinguishes Shift+Tab.
					if event is InputEventKey and previous is InputEventKey:
						var exact = base in ["ui_focus_next", "ui_focus_prev"] and other_base in ["ui_focus_next", "ui_focus_prev"]
						if event.is_match(previous, exact) or previous.is_match(event, exact): return other_base
					elif event is InputEventJoypadButton and previous is InputEventJoypadButton:
						if event.button_index == previous.button_index: return other_base
					elif event is InputEventJoypadMotion and previous is InputEventJoypadMotion:
						if event.axis == previous.axis and signf(event.axis_value) == signf(previous.axis_value): return other_base
	return ""

func capture(event: InputEvent) -> bool:
	if capture_action.is_empty(): return false
	if event.is_action_pressed("ui_cancel"):
		cancel_capture()
		show_inputs()
		return true
	var binding: Dictionary = {}
	if event is InputEventKey and event.pressed and not event.echo:
		binding = {"key": event.physical_keycode if event.physical_keycode else event.keycode, "ctrl": event.ctrl_pressed, "shift": event.shift_pressed, "alt": event.alt_pressed}
	elif event is InputEventJoypadButton and event.pressed:
		binding = {"joy": event.button_index}
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7:
		binding = {"axis": event.axis, "value": signf(event.axis_value)}
	if binding.is_empty(): return false
	var target = capture_action
	if (binding.has("joy") or binding.has("axis")) and InputMap.has_action(target + "_controller"): target += "_controller"
	var conflict = conflicting_action(target, event)
	if not conflict.is_empty():
		cancel_capture()
		show_inputs()
		owner.toast.text = owner.t("native.input_conflict", {"action": owner.t("native.key_" + conflict)})
		owner.toast_time = 5.0
		return true
	apply_binding(target, binding)
	var slots: Dictionary = values.inputs.get(target, {}).duplicate(true)
	if slots.has("key") or slots.has("joy") or slots.has("axis"):
		var old_device = "controller" if slots.has("joy") or slots.has("axis") else "keyboard"
		slots = {old_device: slots}
	slots["controller" if binding.has("joy") or binding.has("axis") else "keyboard"] = binding
	values.inputs[target] = slots
	cancel_capture()
	owner.toast_time = 0.0
	owner.toast.text = ""
	save()
	show_inputs()
	return true

func apply_binding(action: String, binding: Dictionary):
	var event: InputEvent
	if binding.has("axis"):
		event = InputEventJoypadMotion.new()
		event.axis = int(binding.axis)
		event.axis_value = float(binding.value)
	elif binding.has("joy"):
		event = InputEventJoypadButton.new()
		event.button_index = int(binding.joy)
	else:
		event = InputEventKey.new()
		event.physical_keycode = int(binding.get("key", 0))
		event.ctrl_pressed = bool(binding.get("ctrl", false))
		event.shift_pressed = bool(binding.get("shift", false))
		event.alt_pressed = bool(binding.get("alt", false))
	# Keep the other device's binding when remapping keyboard or controller.
	for previous in InputMap.action_get_events(action):
		if (previous is InputEventJoypadButton or previous is InputEventJoypadMotion) == (event is InputEventJoypadButton or event is InputEventJoypadMotion): InputMap.action_erase_event(action, previous)
	InputMap.action_add_event(action, event)
