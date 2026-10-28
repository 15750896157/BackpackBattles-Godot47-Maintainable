extends Node

var windowModes = [
	"windowed",
	"fullscreen",
	"borderless",
	"borderless_maximized"
]

var resolutions = [
	"1280x1024",
	"1920x1080",
	"2560x1440",
	"3840x2160"
]

const DMG_NR_ALL = 0
const DMG_NR_CHAR = 1
const DMG_NR_ITEMS = 2
const DMG_NR_NONE = 3

const PICK_OFFSET = 100.0

enum Setting{

	language = 0,
	opponent_chibis = 1,
	hide_names = 2,
	combat_speed = 3,
	highlight_slots = 4,
	bag_hotswapping = 5,
	damage_numbers = 6,
	stat_icons = 7,
	buff_labels = 8,
	text_effects = 9,
	pick_offset = 10,

	window_mode = 11,
	vsync = 12,
	resolution = 13,
	fps_limit = 14,
	reduce_fps_unfocused = 15,
	software_cursor = 16,
	cursor_size = 17,
	cursor_speed = 18,

	bgm_muted = 19,
	sfx_muted = 20,
	voice_muted = 21,
	bgm_volume = 22,
	sfx_volume = 23,
	voice_volume = 24,
	mute_unfocused = 25,
}

var settingKeys = Setting.keys()

var settings: Array
var defaults: Array
var initializing = true

func _init():
	settings.resize(Setting.size())
	initDefaults()

func initDefaults():
	return load("res://Runtime/Behavior/Utility/SettingsBehavior.gd").initDefaults(self)

func _ready():
	loadConfig()
	call_deferred("ready_deferred")

func loadConfig():
	return load("res://Runtime/Behavior/Features/Utility/SettingsBehavior.gd").loadConfig(self)

func ready_deferred():
	call_deferred("initAll")

func initAll():
	for i in settings.size():
		initVal(i)

	initializing = false

func initVal(setting: int) -> void :
	load("res://Runtime/Behavior/Features/Utility/SettingsBehavior.gd").initVal(self, setting)

func setValStr(setting: String, value) -> void :
	setVal(Setting[setting], value)

func setVal(setting: int, value) -> void :
	load("res://Runtime/Behavior/Utility/SettingsBehavior.gd").setVal(self, setting, value)

func getValStr(setting: String):
	return getVal(Setting[setting])

func getVal(setting: int):
	var methodName = "get_" + settingKeys[setting]
	if has_method(methodName):
		return call(methodName)
	else:
		return settings[setting]

func init_language():
	setVal(Setting.language, Game.getConfigValue("Options", "language", Game.getDefaultLocale()))

func set_language(value):
	Game.setLocale(value)
	return value

func set_opponent_chibis(value):
	Game.call_deferred("setShowChibis", value)
	return value

func set_hide_names(value):

	if Game.OPPONENT:
		if value:
			Game.OPPONENT.hideCharacterName()
		else:
			Game.OPPONENT.showCharacterName()
	return value

func setWindowMode(fullscreen, borderless):
	return load("res://Runtime/Behavior/Utility/SettingsBehavior.gd").setWindowMode(self, fullscreen, borderless)

func clipToScreen():
	return load("res://Runtime/Behavior/Utility/SettingsBehavior.gd").clipToScreen(self)

func set_window_mode(value):
	return load("res://Runtime/Behavior/Features/Utility/SettingsBehavior.gd").set_window_mode(self, value)

func set_vsync(value):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if (value) else DisplayServer.VSYNC_DISABLED)
	return value

func set_software_cursor(value):
	if value:
		Game.cursor = Game.Cursor.SOFTWARE_SMALL
	else:
		Game.cursor = Game.Cursor.HARDWARE_SMALL
	return value

func set_fps_limit(value):
	if value < 10 and value > 0:
		value = 10
	value = clamp(value, 0, 999)
	Engine.max_fps = value
	return value

func set_resolution(value):

	return value

func set_cursor_size(value):
	Game.call_deferred("changeCursorSize", value)
	return value

func set_bgm_muted(value):
	Sound.muteBGM(value)
	return value

func set_sfx_muted(value):
	Sound.muteSFX(value)
	return value

func set_voice_muted(value):
	Sound.muteVoice(value)
	return value

func set_bgm_volume(value):
	Sound.setBGMVolume(value)
	return value

func set_sfx_volume(value):
	Sound.setSFXVolume(value)
	return value

func set_voice_volume(value):
	Sound.setVoiceVolume(value)
	return value
