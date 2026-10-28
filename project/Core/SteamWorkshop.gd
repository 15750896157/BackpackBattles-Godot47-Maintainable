extends Node
class_name SteamLeaderboard
## Local opponent/archive board; no remote requests.
var gotResponse = false
var isComplete = false
var largestSequenceNumber = 0
var parsedRuns = []
var leaderboardHandle = 1
var downloading = false
var downloadQueued = false
var findRetries = 0
var ugcQueryHandle = 0
var ugcHandles = []
var numPages = 0
var curPage = 0
const PAGESIZE = 1000
func _db():
	return get_node("/root/RunDatabase")
func _store():
	return get_node("/root/LocalServices")
func _ready() -> void:
	downloadScores()
func downloadScores() -> void:
	if downloading: return
	downloading = true
	call_deferred("_read_local_board")
func _read_local_board() -> void:
	load("res://Runtime/Behavior/Core/SteamWorkshopBehavior.gd")._read_local_board(self)

func finalize() -> void:
	isComplete = true
	downloading = false
	_db().onSteamRunsReceived()
func hasRuns() -> bool:
	return not parsedRuns.is_empty()
func pushScore(metadata_text: String, sequence: int) -> void:
	load("res://Runtime/Behavior/Core/SteamWorkshopBehavior.gd").pushScore(self, metadata_text, sequence)

func parseMetadata(handle: int, results_returned: int, runArr: Array, lobbyMode: bool) -> void:
	load("res://Runtime/Behavior/Core/SteamWorkshopBehavior.gd").parseMetadata(self, handle, results_returned, runArr, lobbyMode)

func onSteamLeaderboardFindResult(handle: int, _found: int) -> void:
	leaderboardHandle = handle
func onSteamLeaderboardDownloaded(_message: String, _handle: int, _entries: Array) -> void:
	downloadScores()
func requestUGCs() -> void:
	downloadScores()
func onQueryCompleted(_handle, _result, _returned, _total, _cached) -> void:
	finalize()
func onUgcUpdated() -> void:
	downloadScores()
func onSteamLeaderboardUploaded(_result, _handle, _score) -> void:
	downloadScores()
func onSteamLeaderboardUGCSet(_handle, _result) -> void:
	pass
