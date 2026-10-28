extends Node

signal lobby_created
signal lobby_closed
signal lobby_left
signal lobby_joined
signal lobby_join_confirmed
signal join_result
signal lobby_join_failed
signal config_changed
signal member_added
signal member_removed
signal kicked
signal found_opponent
signal score_changed
signal start_countdown
signal update_ready_counter
signal lobby_results
signal all_end_results_received

enum JoinResult{
	Confirmed = 0,
	Unconfirmed = 1,
	Restricted_AlreadyStarted = 2,
	Restricted_HostLeft = 3,
	Restricted_Banned = 4,
	Error_CodeInvalid = 5,
	Error_VersionMismatch = 6
}

enum ResponseCode{
	Ok = 0,
	AlreadyStarted = 1,
	MemberLimitReached = 2,
	ManualKick = 3
}

enum PartyState{
	NoParty = 0,
	Hosting = 1,
	Connecting = 2,
	Connected = 3,
	Reconnecting = 4
}

enum MessageType{
	Member_Joined = 0,
	Member_Left = 1,
	Member_Reconnected = 2,
	Member_RoundData = 3,
	Member_RoundResult = 4,
	Host_GameStart = 5,
	Host_Time = 6,
	Host_CombatStart = 7,
	Host_Kicked_Member = 8

}

enum LobbyJoinedResult{
	SUCCESS = 1,
	DOESNT_EXIST = 2,
	NOT_ALLOWED = 3,
	FULL = 4,
	ERROR = 5,
	BANNED = 6,
	LIMITED = 7,
	CLAN_DISABLED = 8,
	COMMUNITY_BAN = 9,
	MEMBER_BLOCKED_YOU = 10,
	YOU_BLOCKED_MEMBER = 11,
	RATE_LIMITED = 15
}

enum ChatEntryType{
	ChatMsg = 1,
	Typing = 2,
	InviteGame = 3,
	Emote = 4,
	LeftConversation = 6,
	Entered = 7,
	WasKicked = 8,
	WasBanned = 9,
	Disconnected = 10,
	HistoricalChat = 11,
	LinkBlocked = 14
}

enum ChatMemberChange{
	Joined = 1,
	Left = 2,
	Disconnected = 4,
	Kicked = 8,
	Banned = 10
}

enum MatchMaking{
	Random = 0,
	Elimination = 1,
	RoundRobin = 2,
	EvenStats = 3,
	Strongest = 4,
	PrioritizeHost = 16
}

const scoreboardScene = preload("res://Interface/Lobbies/LobbyScoreboard.tscn")
const scoreboardButtonScene = preload("res://Interface/Lobbies/ScoreboardButton.tscn")
const lobbyTimerScene = preload("res://Interface/Lobbies/LobbyTimer.tscn")
const roundDurationCurve = preload("res://Interface/Lobbies/RoundDuration.tres")
const COMBAT_TIME= 20.0
const STARTGAME_COUNTDOWN= 3.0
const MIN_MEMBERS= 2
const MAX_MEMBERS= 99
const USE_MEMBER_UGC= false
const READ_MEMBER_UGC= false
const retryTime = 10.0
const DELAY_COMPENSATION = 0.2
const memberInfoKey = "A"
const speedConfigKey = "B"
const sizeConfigKey = "C"
const customRulesConfigKey = "D"
const matchingConfigKey = "E"
const nextFightTimeKey = "F"

const resultsKey = "G"
const sqnKey = "H"
const membersKey = "I"
const membersSqnKey = "J"
const READY = "K"
const hostUgcFields = ["id", "lobbyId", "v"]
var symbolToNumber: Dictionary

var curLobbyId: int
var curPartyUgcId: int
var memberUgcItem = null
var ugcItem = null
var memberUgcId: int
var members: Array
var memberData: Dictionary
var memberList: Array
var partyState: int
var hostSteamId: int
var reconnecting: bool
var liveReconnecting: bool
var joinConfirmed: bool
var gameHasStarted: bool
var onResultsScreen: bool
var ignoreLobbyUpdates: bool
var lastFightTimestamp: String
var feasibleRuns: Array
var opponentHistory: Array
var hostUgcQueryHandle: int
var partyUgcMetadata: Dictionary
var metadataSqn: int
var memberMetadataSqn: int
var opponentRuns: Array
var opponentQueryHandle = 0

var H_hostUgcId: int
var H_hostUgcMetadata: Dictionary

var lobbyTimer = null
var scoreboardButton = null
var scoreboardNode = null
var scoreboard = null

var lobbySize= 20
var lobbySpeed = SpeedLevel.Normal
var customRules: String
var matchMaking: int = MatchMaking.Random
var prioritizeHost: bool
var _local_clock_save_elapsed = 0.0

enum SpeedLevel{
	Slowest = 1,
	Slower = 2,
	Slow = 3,
	Normal = 4,
	Fast = 5,
	Faster = 6,
	Fastest = 7
}

var speedFactors = {
	SpeedLevel.Slowest: 4.0,
	SpeedLevel.Slower: 2.5,

	SpeedLevel.Slow: 1.5,
	SpeedLevel.Normal: 1.0,
	SpeedLevel.Fast: 0.75,
	SpeedLevel.Faster: 0.5,
	SpeedLevel.Fastest: 0.3

}

func _ready():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd")._ready(self)

func _process(delta):
	_local_clock_save_elapsed += delta
	if _local_clock_save_elapsed >= 5.0:
		_local_clock_save_elapsed = 0.0
		_save_local_room_clock()

func _save_local_room_clock():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd")._save_local_room_clock(self)

func _restore_local_room_clock():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd")._restore_local_room_clock(self)

const symbolSize = 5
const numSymbols = int(ceil(64.0 / symbolSize))
const mod = int(pow(2, symbolSize))
const baseValue = 3550000000

func idToString(id: int) -> String:
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").idToString(self, id)

func idFromString(idAsString: String):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").idFromString(self, idAsString)

func isInLobby() -> bool:
	return curLobbyId != 0

func isActiveMember() -> bool:
	return partyState == PartyState.Connected or partyState == PartyState.Hosting

func getNumMembers() -> int:
	return memberData.size()

func isMemberHost(memberSteamId) -> bool:
	return hostSteamId == memberSteamId

func isMe(id) -> bool:
	return id == SteamHelper.STEAM_ID

func isHost() -> bool:
	return hostSteamId == SteamHelper.STEAM_ID

func isClient() -> bool:
	return not isHost()

func setReady():
	getOwnMemberData().setReady(true)
	setLobbyMemberData(str(Game.curRound), READY)
	emit_signal("update_ready_counter")
	checkAllReady()

func prepareCombat():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").prepareCombat(self)

func startCombat():

	reconnecting = false
	if isHost():
		setRoundAndTimeMetadata(Game.curRound)

func setRoundAndTimeMetadata(roundI):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").setRoundAndTimeMetadata(self, roundI)

func setMemberListMetadata():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").setMemberListMetadata(self)

func getPlayerMetadata() -> String:
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").getPlayerMetadata(self)

func pushRoundToUgc():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").pushRoundToUgc(self)

func onUgcUpdated():
	if not READ_MEMBER_UGC: return

	print("Round pushed!")

	if isHost():
		findOpponents()
	else:
		requestHostUgc()

func findOpponents():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").findOpponents(self)

func onOpponentQueryCompleted(handle, result, results_returned,
	total_matching, cached: bool):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onOpponentQueryCompleted(self, handle, result, results_returned, total_matching, cached)

func getNextOpponentData() -> Dictionary:
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").getNextOpponentData(self)

func createParty():
	createLobby()

func createLobby():
	ignoreLobbyUpdates = false
	hostSteamId = SteamHelper.STEAM_ID
	print("Trying to create lobby.")

	Steam.createLobby(3, MAX_MEMBERS + 20)

func getVersionString() -> String:
	var version = Game.VERSION + Game.SUBVERSION
	if Game.BETA:
		version += "BETA"
	return version

func onLobbyCreated(result, lobbyId):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onLobbyCreated(self, result, lobbyId)

func createMemberUgc():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").createMemberUgc(self)

func onMemberUgcCreated():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").onMemberUgcCreated(self)

func finishJoining():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").finishJoining(self)

func createHostUgc():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").createHostUgc(self)

func onHostUgcCreated():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").onHostUgcCreated(self)

func onHostUgcCreationFailed():
	print("Lobby creation failed")

func joinParty(lobbyCode: String):
	ignoreLobbyUpdates = false
	print("Trying to join lobby as member ", lobbyCode)
	partyState = PartyState.Connecting
	curPartyUgcId = idFromString(lobbyCode)
	requestHostUgc()

func getHostId() -> int:
	return hostSteamId

func getHostUgcId() -> int:
	return H_hostUgcId if isHost() else curPartyUgcId

func getLobbyId() -> int:
	return curLobbyId

func requestHostUgc():
	hostUgcQueryHandle = Steam.createQueryUGCDetailsRequest([curPartyUgcId])
	Steam.setReturnMetadata(hostUgcQueryHandle, true)
	Steam.sendQueryUGCRequest(hostUgcQueryHandle)

func onInvalidCode():
	Util.showPopupMessage("STATUS_Invalid")
	emit_signal("join_result", JoinResult.Error_CodeInvalid)
	releaseQuery()

func onHostUgcQueryCompleted(handle, result, results_returned,
	total_matching, cached: bool):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onHostUgcQueryCompleted(self, handle, result, results_returned, total_matching, cached)

func releaseQuery():
	Steam.releaseQueryUGCRequest(hostUgcQueryHandle)
	hostUgcQueryHandle = 0

func joinLobby(lobbyId):
	print("Trying to join lobby")
	Steam.joinLobby(int(lobbyId))

func onLobbyJoined(lobbyId, _permissions, locked, response):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onLobbyJoined(self, lobbyId, _permissions, locked, response)

func onJoinFailed():
	if liveReconnecting:
		print("Could not reconnect after disconnect.")
		onLobbyClosed()
	else:
		Steam.leaveLobby(curLobbyId)
		resetState()

func resetState():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").resetState(self)

func leaveLobby():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").leaveLobby(self)

func onLobbyChatUpdate(lobbyId, changedId, makingChangeId, chatState):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onLobbyChatUpdate(self, lobbyId, changedId, makingChangeId, chatState)

func sendChatMessage(message: String):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").sendChatMessage(self, message)

func chatMessageReceived(lobbyId: int, memberId: int, buffer: String, chatType: int):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").chatMessageReceived(self, lobbyId, memberId, buffer, chatType)

func onLobbyDataUpdate(success: int, lobbyId, memberId):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onLobbyDataUpdate(self, success, lobbyId, memberId)

func makeHostOwner():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").makeHostOwner(self)

func startCountdown():
	sendStartCountdownMessage()
	onStartCountdown()
	lobbyTimer.initTimer()
	setRoundAndTimeMetadata(0)
	updateHostUgc()

func onStartCountdown():
	gameHasStarted = true
	ensureTimer()
	emit_signal("start_countdown")

func onGameStart():
	if Game.curMode == Game.Mode.Lobbies:
		ensureScoreboard()

func ensureScoreboard():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").ensureScoreboard(self)

func deleteScoreboard():
	scoreboardNode.queue_free()
	scoreboard.queue_free()
	scoreboardNode = null
	scoreboard = null
	scoreboardButton = null

func ensureTimer():
	if lobbyTimer == null:
		print("create timer")
		lobbyTimer = lobbyTimerScene.instantiate()
		Game.startCombatButton.add_sibling(lobbyTimer)

func countReadyMembers() -> int:
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").countReadyMembers(self)

func allOpponentsReady() -> bool:
	return countReadyMembers() == getNumMembers()

func allOpponentsSubmitted() -> bool:
	return countReceivedRounds(Game.curRound) == getNumMembers()

func getMissingOpponentNames() -> Array:
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").getMissingOpponentNames(self)

func allOpponentsResultsReceived() -> bool:
	return countReceivedRoundResults(getCurRound()) == getNumMembers()

func getCurRound() -> int:
	return int(min(Game.curRound, Game.MAX_ROUNDS_LOBBIES))

func canAddMember(_memberId) -> int:

	if gameHasStarted:
		return ResponseCode.AlreadyStarted

	if getNumMembers() >= getLobbySize():
		return ResponseCode.MemberLimitReached

	return ResponseCode.Ok

func addMember_Host(steamId: int, memberUgcIdAsString: String = ""):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").addMember_Host(self, steamId, memberUgcIdAsString)

func onMemberListChanged():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onMemberListChanged(self)

func prepareMemberData(steamId: int, ugcId = 0):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").prepareMemberData(self, steamId, ugcId)

func updateMemberData(steamId, metadata: String, ugcId = 0):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").updateMemberData(self, steamId, metadata, ugcId)

func removeMember_Host(steamId: int):
	removeMember(steamId)

	setMemberListMetadata()

func removeMember(steamId: int):
	if not steamId in memberData:

		return
	memberData.erase(steamId)
	memberList.erase(steamId)
	onMemberRemoved(steamId)
	checkEnterCombat()

func onMemberRemoved(steamId):
	emit_signal("member_removed", steamId)
	recalculateRanking()
	emit_signal("score_changed")

func kickMember(steamId):
	if not isHost(): return
	sendKickMessage(steamId, ResponseCode.ManualKick)
	removeMember_Host(steamId)

func onSelfKicked(responseCode):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").onSelfKicked(self, responseCode)

func onLobbyClosed():
	if not onResultsScreen:
		ignoreLobbyUpdates = true
		emit_signal("lobby_closed")
		Util.showPopupMessage("ERROR_LobbyClosed")
		Game.forceLeaveLobby()

func setLobbyData_sqn(key: String, value: String, _sqnKey: String = sqnKey) -> bool:
	metadataSqn += 1
	setLobbyData(key, value)
	return setLobbyData(_sqnKey, str(metadataSqn), false)

func setLobbyData(key: String, value: String, _print: bool = true) -> bool:
	if _print:
		print("set: ", key, " -> ", value)
	return Steam.setLobbyData(curLobbyId, key, value)

func getLobbyData(key: String, _print: bool = true) -> String:
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").getLobbyData(self, key, _print)

func setLobbyMemberData(key: String, value: String, _print: bool = true):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").setLobbyMemberData(self, key, value, _print)

func getLobbyMemberData(playerId: int, key: String, _print: bool = true) -> String:
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").getLobbyMemberData(self, playerId, key, _print)

func onGameDataUpdated():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onGameDataUpdated(self)

func getMemberData(steamId):
	return memberData[steamId]

func getOwnMemberData() -> LobbyMemberData:
	return getMemberData(SteamHelper.STEAM_ID)

func updateOwnMetadata():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").updateOwnMetadata(self)

func updateHostUgc():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").updateHostUgc(self)

func onHostUgcUpdated():
	print("updated")
	pass

func createMessage(type: int, arguments = null):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").createMessage(self, type, arguments)

func createAndSendMessage(type: int, arguments = null):
	if ignoreLobbyUpdates: return
	var msg = createMessage(type, arguments)
	sendChatMessage(msg)

func sendJoinMessage():
	createAndSendMessage(MessageType.Member_Joined, [memberUgcId, Game.getPlayerName()])

func sendLeaveMessage():
	createAndSendMessage(MessageType.Member_Left)

func sendReconnectMessage():
	createAndSendMessage(MessageType.Member_Reconnected)

func sendRoundDataMessage(roundNum, metaDataString):
	createAndSendMessage(MessageType.Member_RoundData, [roundNum, metaDataString])

func sendRoundResultMessage(roundNum, result):
	createAndSendMessage(MessageType.Member_RoundResult, [roundNum, result])

func sendStartCountdownMessage():
	createAndSendMessage(MessageType.Host_GameStart)

func sendKickMessage(steamId: int, responseCode: int):
	createAndSendMessage(MessageType.Host_Kicked_Member, [steamId, responseCode])

func resultsToString() -> String:
	var resultsAsString= ""
	for result in Game.roundResults:
		resultsAsString += str(result)
	return resultsAsString

func collectRoundData():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").collectRoundData(self)

func countReceivedRounds(forRound):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").countReceivedRounds(self, forRound)

func onOpponentRoundsReceived():

	emit_signal("found_opponent")

func checkAllReady():
	if allOpponentsReady():
		lobbyTimer.forwardTo(2)

func checkEnterCombat():

	if allOpponentsSubmitted():
		onOpponentRoundsReceived()

func countReceivedRoundResults(forRound):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").countReceivedRoundResults(self, forRound)

func onOpponentResultsReceived():
	print("all end results received")
	emit_signal("all_end_results_received")
	ignoreLobbyUpdates = true

var rematchPenalty = [1, 0.7, 0.4, 0.1, 0]
var rematchPenalty_RoundRobin = range(18, 1, - 1)
var rematchPenalty_EvenStats = [3, 2, 1, 0]
var rematchPenalty_Strongest = [0.8, 0.4, 0.2, 0]
var hostRematch = [0, 0, 0, 0, 0.2, 0.4, 0.6, 0.8, 1]

func pickOpponent() -> LobbyMemberData:
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").pickOpponent(self)

func getRematchPenalty(opponentData, penalties: Array) -> float:
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").getRematchPenalty(self, opponentData, penalties)

func setConfigDefault_Host():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").setConfigDefault_Host(self)

func onConfigUpdated():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onConfigUpdated(self)

func getSpeed():
	return lobbySpeed

func setSpeed_Host(speed):
	setSpeed(speed)
	if isInLobby():
		setLobbyData_sqn(speedConfigKey, str(lobbySpeed))
	emit_signal("config_changed")

func setSpeed(speed):
	lobbySpeed = speed
	print("Set Speed to ", lobbySpeed)

func getLobbySize() -> int:
	return lobbySize

func setLobbySize_Host(size: int):
	setLobbySize(size)
	if isInLobby():
		setLobbyData_sqn(sizeConfigKey, str(size))
	emit_signal("config_changed")

func setLobbySize(size: int):
	lobbySize = clamp(size, MIN_MEMBERS, MAX_MEMBERS)
	print("Max. members set to ", lobbySize)

func setCustomRules_Host(rules: String):
	setCustomRules(rules)
	if isInLobby():
		setLobbyData_sqn(customRulesConfigKey, rules)
	emit_signal("config_changed")

func setCustomRules(rules: String):
	customRules = rules
	if rules == "":
		CustomRules.reset()
	else:
		CustomRules.fromString(customRules)

func getMatchmaking() -> int:
	return matchMaking

func getPrioritizeHost() -> bool:
	return prioritizeHost

func setMatchMaking_Host(_matchMaking: int, _prioritizeHost):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").setMatchMaking_Host(self, _matchMaking, _prioritizeHost)

func setMatchMaking(_matchMaking: int, _prioritizeHost: bool):
	matchMaking = _matchMaking
	prioritizeHost = _prioritizeHost
	print("Matchmaking: ", Util.enumToString(MatchMaking, matchMaking), " - prioritize host: ", prioritizeHost)

func getRoundDuration(roundNum) -> float:
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").getRoundDuration(self, roundNum)

func calcRunDuration() -> float:
	var dur = 0.0
	for roundNum in Game.MAX_ROUNDS_LOBBIES:
		dur += getRoundDuration(roundNum)
	return dur

func getRunDuration_Minutes() -> int:
	var totalTime = calcRunDuration()
	return int(round((totalTime + 60) / 60.0))

func getAverageRoundDuration_seconds() -> int:
	var totalTime = calcRunDuration()
	return int(snapped(round(totalTime / 18.0), 5))

func onOwnClassChanged():
	if isInLobby():
		updateOwnMetadata()

func onFightFinished(roundResult: int):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").onFightFinished(self, roundResult)

func getResultScore():
	return getOwnMemberData().getCurrentScore()

func getResultRank():
	return getOwnMemberData().curRanking

func getMemberRanking(steamId):
	return memberData[steamId].curRanking

func recalculateRanking():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd").recalculateRanking(self)

func tryReconnect():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd").tryReconnect(self)

const MSG_DELIMITER = ","

const symbols = [
	"a", "b", "c", "d",
	"f", "g", "h", "j",
	"k", "l", "m", "n", "p",
	"q", "r", "s", "t", "u",
	"v", "w", "x", "y", "z",
	"1", "2", "3", "4", "5",
	"6", "7", "8", "9"
]

@onready var symbolDict = Util.arrayAsIndexDict(symbols)

class MemberSorter:
	static func sort(member1: LobbyMemberData, member2: LobbyMemberData):
		return member1.getCurrentScore() > member2.getCurrentScore()

func _exit_tree():
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd")._exit_tree(self)

const LOCAL_GUEST_ID = 3550000100
func _ensure_local_guest():
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd")._ensure_local_guest(self)

func _sync_local_guests(round_metadata: String):
	return load("res://Runtime/Behavior/Features/Utility/LobbiesBehavior.gd")._sync_local_guests(self, round_metadata)

func _finish_local_guest_round(result: int):
	return load("res://Runtime/Behavior/Utility/LobbiesBehavior.gd")._finish_local_guest_round(self, result)

