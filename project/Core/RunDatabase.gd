extends Node

const UNRANKED_RATING = - 1000

const RUN_BOARD = "bpb-runs3"
const BETA_BOARD = "bpb-runs1"
const DEMO_BOARD = "bpb-runs1"
const MIN_CACHE_ENTRIES = 30

const OUTDATED_runCachePath = "user://runs.cache"
const OUTDATED_runCachePath_BETA = "user://beta/runs.cache"
const steamCachePath = "user://runs_steam.cache"
const silentwolfCachePath = "user://runs_sw.cache"
const steamCachePath_BETA = "user://beta/runs_steam.cache"
const silentwolfCachePath_BETA = "user://beta/runs_sw.cache"
const steamCachePath_PLAYTEST = "user://playtest/runs_steam.cache"
const silentwolfCachePath_PLAYTEST = "user://playtest/runs_sw.cache"

var steamLeaderboard = null
var lobbies = null

var swSequenceNumber: int = 1
var runsFromCache = []
var silentwolfRuns = []
var gotSwResponse = false

var rounds = []

const DELAY_AFTER_RECEIVE = 20 * 60
var delayAfterRequest: float

var resendTimer
var runsReceivedTime = - INF
var runRequestTime = - INF

var feasibleRuns = []
var curOpponentIndex = 0

var faceDarkReflection= false

const rematchSameOpponentTimeout = 12
var recentOpponentRuns = []
var recentOpponentNames = []

@onready var totalNumGems = BitStream.binaryCeil(ItemBook.getNumGems() + 1)
@onready var emptySocketId = totalNumGems - 1

var facedNoConnectionDarkReflection: int

var statisticsMode = false

func getParsedRuns():
	if steamLeaderboard != null and not steamLeaderboard.parsedRuns.is_empty():
		return steamLeaderboard.parsedRuns
	return silentwolfRuns

func hasConnected():
	return true # Local storage is immediately available.

func _ready() -> void:
	load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd")._ready(self)

func ready_deferred():
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").ready_deferred(self)

func getLeaderboard():
	if Game.DEMO:
		return DEMO_BOARD
	if Game.BETA:
		return BETA_BOARD
	else:
		return RUN_BOARD

func sendRunRequest():
	runRequestTime = Util.clockTime
	if steamLeaderboard != null: steamLeaderboard.downloadScores()
	SilentWolf.Scores.get_high_scores(2000, getLeaderboard())

func parseSingleScore(score, steam: bool, lobbyMode: bool = false):
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").parseSingleScore(self, score, steam, lobbyMode)

func parseScores(scores):
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd").parseScores(self, scores)

func onRunsReceived():
	Game.connectingLabel.hide()
	resendTimer.stop()
	runsReceivedTime = Util.clockTime

func onSilentwolfRunsReceived(_board, scores):
	if str(_board) != getLeaderboard():
		return
	silentwolfRuns = parseScores(scores)
	gotSwResponse = true
	onRunsReceived()

func checkSteamRunsReceived():
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd").checkSteamRunsReceived(self)

func onSteamRunsReceived():
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").onSteamRunsReceived(self)

func getRunCachePath(_steam: bool):
	return "user://local_services/boards.json"

func cacheRuns(_runs, _steam: bool):
	pass # LocalServices already persists records atomically.

func loadCachedRuns():
	runsFromCache = parseScores(LocalServices.scores(getLeaderboard()))

func startRun():
	rounds.clear()
	facedNoConnectionDarkReflection = 0
	recentOpponentRuns.clear()

func getNextOpponentData(roundReduction: int) -> Dictionary:
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").getNextOpponentData(self, roundReduction)

func _normalize_local_practice(round_data: Dictionary, run) -> Dictionary:
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd")._normalize_local_practice(self, round_data, run)

func getDarkReflectionData() -> Dictionary:
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").getDarkReflectionData(self)

func notifyOpponentCorrupt():
	if not recentOpponentRuns.is_empty():
		recentOpponentRuns.pop_back()

func getNumFeasibleRuns() -> int:
	var num = 0
	for run in getParsedRuns():
		if run.getNumRounds() >= Game.curRound:
			num += 1
	return num

func sortOpponents():
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").sortOpponents(self)

func getFallbackOpponent() -> BitStream:
	var string = serializeRound()
	var bitStream = BitStream.new()
	bitStream.fromGodotString(string)
	return bitStream

func serializeCurrentRound():
	var current = serializeRound()
	rounds.push_back(current)
	_record_local_snapshot("player_recorded")
	return current

func getRoundData(roundNum):
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd").getRoundData(self, roundNum)

func serializeRound() -> String:
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").serializeRound(self)

func serializeMetadata() -> BitStream:
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").serializeMetadata(self)

func pushRun():
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd").pushRun(self)

func getRunDict() -> Dictionary:
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd").getRunDict(self)

func getPlayerName() -> String:
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd").getPlayerName(self)

func actuallyPersistRun(playerName, data: Dictionary):
	return load("res://Runtime/Behavior/Features/Core/RunDatabaseBehavior.gd").actuallyPersistRun(self, playerName, data)

const replaceNames = [
	"SifdFan69",
	"team splattercat",
	"love wanderbots",
	"northerlion pog",
	"siiiiiifd",
	"retrofan",
	"tellsplattercat",
	"the egg",
	"Skoottie GOAT",
	"Hi SAG",
	"2Late4Miracle",
	"nice try net",
	"DolphinPhysicist",
	"Stanz Stan",
	"AMAZing",
	"Dogdogdog",
	"Have Fun Hafu",
	"Sodapops",
	"Bahrooooo",
	"Celery",
	"Tide of Tim",
	"Rattatatan",
	"let him cook",
	"hi shinji",
	"Panda in a bag",
	"Asmodaimond",
	"buy the game lol",
	"backpack enjoyer",
	"gratis151ml",
	"ede adé",
	"Maxim Aal",
	"Grubtor",
	"It's me Tim",
	"Hi Mark",
	"Huge Goobies",
	"Backpack Bob",
	"Bob's Backpack",
	"Backpackcoach",
	"Bearenstein Hair",
	"Dan Gooseling",
	"Raketenbohne",
	"FootofBlood",
	"xcuse me",
	"Threebeers",
	"Kai Zen",
	"Rolf"
]

class Matchmaker:

	static func sort_ascending(run1: RunData, run2: RunData):
		return run1.mmScore < run2.mmScore

func _seed_local_opponents():
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd")._seed_local_opponents(self)

func _make_local_run(player_name: String, player_id: String):
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd")._make_local_run(self, player_name, player_id)

func _record_local_snapshot(source: String):
	return load("res://Runtime/Behavior/Core/RunDatabaseBehavior.gd")._record_local_snapshot(self, source)

