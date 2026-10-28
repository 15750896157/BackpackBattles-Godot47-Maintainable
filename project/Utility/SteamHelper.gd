extends Node

const achievementPopupScene = preload("res://Interface/AchievementPopup.tscn")

var IS_INIT: bool = false
var IS_OWNED: bool = false
var IS_ONLINE: bool = false
var IS_FREE_WEEKEND: bool = false
var STEAM_ID: int = 0
var STEAM_NAME: String = ""
var GAME_LANG: String
var LOCALE: String
var STATS_RECEIVED = false
var SEQUENCE_NUM= 0
var SEQUENCE_NUM_LOBBIES= 0
var STORESTATS_READYTIME = 0.0
var APP_ID: int
var STEAMDECK: bool = false

var achievementQueue= []
var achievementTimer
var unlockedThisSession= {}

const MAIN_ID = 2427700
const DEMO_ID = 2444170
const PLAYTEST_ID = 2747170

const langCodes = {
	"english": "en",
	"schinese": "zh_Hans_CN",
	"japanese": "ja",
	"koreana": "ko",
	"german": "de",
	"tchinese": "zh_Hant_TW",
	"french": "fr",
	"brazilian": "pt",
	"russian": "ru",
	"latam": "es"
}

func is_init():
	return IS_INIT

func _process(_delta: float) -> void :

	Steam.run_callbacks()

func isIDValid():
	return STEAM_ID != 0

func _ready() -> void:
	load("res://Runtime/Behavior/Utility/SteamHelperBehavior.gd")._ready(self)

func onInitFailed():
	push_warning("Local profile initialization failed")

func onStatsReceived(game, results, user):

	getAllStats()

func getAllStats():
	return load("res://Runtime/Behavior/Features/Utility/SteamHelperBehavior.gd").getAllStats(self)

func getSequenceNum(mode) -> int:
	if mode == Game.Mode.Lobbies:
		return SEQUENCE_NUM_LOBBIES
	else:
		return SEQUENCE_NUM

func incrementSequenceNumber(mode) -> void :
	load("res://Runtime/Behavior/Features/Utility/SteamHelperBehavior.gd").incrementSequenceNumber(self, mode)

func storeStats():
	var res = Steam.storeStats()
	Util.eprint("store stats ", res)

func updateRichPresence():
	return load("res://Runtime/Behavior/Utility/SteamHelperBehavior.gd").updateRichPresence(self)

func addRichPresence(key, value):
	Steam.setRichPresence(key, value)

func canUnlock(allowInCustom = false) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/SteamHelperBehavior.gd").canUnlock(self, allowInCustom)

func unlockAchievement(aName: String, allowInCustom = false):
	return load("res://Runtime/Behavior/Utility/SteamHelperBehavior.gd").unlockAchievement(self, aName, allowInCustom)

func showNextAchievement():
	return load("res://Runtime/Behavior/Features/Utility/SteamHelperBehavior.gd").showNextAchievement(self)

func hasAchievement(aName: String) -> bool:
	if not STATS_RECEIVED: return true

	var curState = Steam.getAchievement(aName)
	return curState.achieved

func changeStat(statName: String, amount: int):
	return load("res://Runtime/Behavior/Features/Utility/SteamHelperBehavior.gd").changeStat(self, statName, amount)

func dropItem():
	return load("res://Runtime/Behavior/Features/Utility/SteamHelperBehavior.gd").dropItem(self)

