extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Settings.gd")

static func initDefaults(subject: Receiver):
	subject.defaults.resize(subject.Setting.size())
	subject.defaults[subject.Setting.language] = "en"
	subject.defaults[subject.Setting.opponent_chibis] = false
	subject.defaults[subject.Setting.hide_names] = false
	subject.defaults[subject.Setting.combat_speed] = 1.0
	subject.defaults[subject.Setting.highlight_slots] = true
	subject.defaults[subject.Setting.bag_hotswapping] = false
	subject.defaults[subject.Setting.damage_numbers] = subject.DMG_NR_ALL
	subject.defaults[subject.Setting.stat_icons] = true
	subject.defaults[subject.Setting.buff_labels] = true
	subject.defaults[subject.Setting.text_effects] = true

	if OS.has_feature("mobile"):
		subject.defaults[subject.Setting.pick_offset] = 1.0
	else:
		subject.defaults[subject.Setting.pick_offset] = 0.0

	subject.defaults[subject.Setting.window_mode] = "fullscreen"
	subject.defaults[subject.Setting.vsync] = true
	subject.defaults[subject.Setting.resolution] = "1920x1080"
	subject.defaults[subject.Setting.fps_limit] = 144
	subject.defaults[subject.Setting.reduce_fps_unfocused] = true
	subject.defaults[subject.Setting.software_cursor] = false
	subject.defaults[subject.Setting.cursor_size] = 0.5
	subject.defaults[subject.Setting.cursor_speed] = 1.0
	subject.defaults[subject.Setting.bgm_muted] = false
	subject.defaults[subject.Setting.sfx_muted] = false
	subject.defaults[subject.Setting.voice_muted] = false
	subject.defaults[subject.Setting.bgm_volume] = 0.3
	subject.defaults[subject.Setting.sfx_volume] = 0.3
	subject.defaults[subject.Setting.voice_volume] = 0.3
	subject.defaults[subject.Setting.mute_unfocused] = false

static func setVal(subject: Receiver, setting: int, value) -> void :
	var methodName = "set_" + subject.settingKeys[setting]
	if subject.has_method(methodName):
		value = subject.call(methodName, value)

	subject.settings[setting] = value
	if value != subject.defaults[setting] or setting == subject.Setting.language:
		Game.setConfigValue("Options", subject.settingKeys[setting], value)
	else:
		Game.eraseConfigValue("Options", subject.settingKeys[setting])

static func setWindowMode(subject: Receiver, fullscreen, borderless):
	if ((subject.get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (subject.get_window().mode == Window.MODE_FULLSCREEN)) != fullscreen:
		subject.get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (fullscreen) else Window.MODE_WINDOWED

	if subject.get_window().borderless != borderless:
		subject.get_window().borderless = (borderless)

	if subject.initializing:
		if not fullscreen:
			var screen = Game.getConfigValue("Options", "screen", null)
			if screen != null:
				subject.get_window().set_current_screen(screen)

			var windowPos = Game.getConfigValue("Options", "window_position", null)
			if windowPos != null:
				subject.get_window().set_position(windowPos)

			var windowSize = Game.getConfigValue("Options", "window_size", null)
			if windowSize != null:
				subject.get_window().set_size(windowSize)

static func clipToScreen(subject: Receiver):

	if subject.get_window().current_screen > DisplayServer.get_screen_count() - 1:
		print("screen count exceeded - #screens: ", DisplayServer.get_screen_count())
		subject.get_window().current_screen = 0

	var screenSize = DisplayServer.screen_get_size()
	var windowSize = subject.get_window().get_size()
	windowSize.x = clamp(windowSize.x, 800.0, screenSize.x)
	windowSize.y = clamp(windowSize.y, 450.0, screenSize.y)
	subject.get_window().set_size(windowSize)

	var windowPos = subject.get_window().get_position()
	var screenPos = DisplayServer.screen_get_position()

	var screenBottomRight = screenPos + screenSize
	var windowBottomRight = windowPos + windowSize
	var overshoot = windowBottomRight - screenBottomRight
	if overshoot.x > 0:
		windowPos.x -= overshoot.x
	if overshoot.y > 0:
		windowPos.y -= overshoot.y

	windowPos.x = max(screenPos.x, windowPos.x)
	windowPos.y = max(screenPos.y, windowPos.y)
	subject.get_window().set_position(windowPos)
