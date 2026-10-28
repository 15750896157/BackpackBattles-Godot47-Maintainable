extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Settings.gd")

static func loadConfig(subject: Receiver):
	for setting in subject.Setting:
		var index = subject.Setting[setting]
		subject.settings[index] = Game.getConfigValue("Options", setting, subject.defaults[index])

static func initVal(subject: Receiver, setting: int) -> void :
	var methodName = "init_" + subject.settingKeys[setting]
	if subject.has_method(methodName):
		subject.call(methodName)
	else:
		subject.setVal(setting, subject.settings[setting])

static func set_window_mode(subject: Receiver, value):
	if not OS.has_feature("web"):

		match value:
			"fullscreen":
				subject.setWindowMode(true, false)
			"borderless":
				subject.setWindowMode(false, true)
				subject.clipToScreen()
			"borderless_maximized":
				subject.setWindowMode(true, true)
			"windowed":
				subject.setWindowMode(false, false)
				subject.clipToScreen()
	return value
