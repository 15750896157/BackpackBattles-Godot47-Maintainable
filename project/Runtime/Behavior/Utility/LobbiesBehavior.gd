extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Lobbies.gd")

static func _ready(subject: Receiver):
	subject.process_mode = Node.PROCESS_MODE_ALWAYS

	Steam.connect("ugc_query_completed", Callable(subject, "onOpponentQueryCompleted"))
	Steam.connect("ugc_query_completed", Callable(subject, "onHostUgcQueryCompleted"))

	Steam.connect("lobby_created", Callable(subject, "onLobbyCreated"))
	Steam.connect("lobby_joined", Callable(subject, "onLobbyJoined"))
	Steam.connect("lobby_chat_update", Callable(subject, "onLobbyChatUpdate"))
	Steam.connect("lobby_message", Callable(subject, "chatMessageReceived"))
	Steam.connect("lobby_data_update", Callable(subject, "onLobbyDataUpdate"))

	Game.connect("character_changed", Callable(subject, "onOwnClassChanged"))
	Game.connect("random_character_changed", Callable(subject, "onOwnClassChanged"))
	Game.connect("fresh_run_started", Callable(subject, "onGameStart"))
	Game.connect("combat_end", Callable(subject, "onFightFinished"))

	for i in subject.symbols.size():
		subject.symbolToNumber[subject.symbols[i]] = i

	subject.resetState()

static func _save_local_room_clock(subject: Receiver):
	if not subject.isInLobby() or not subject.gameHasStarted or subject.ignoreLobbyUpdates or Game.curMode != Game.Mode.Lobbies:
		return
	if not is_instance_valid(subject.lobbyTimer):
		return
	var room = LocalServices.room(subject.curLobbyId)
	if not room.is_empty():
		room["local_remaining"] = maxf(2.0, subject.lobbyTimer.remainingRoundTime)
		room["local_round"] = Game.curRound
		LocalServices.commit("rooms")

static func _restore_local_room_clock(subject: Receiver):
	var room = LocalServices.room(subject.curLobbyId)
	if room.is_empty() or not is_instance_valid(subject.lobbyTimer):
		return
	var default_remaining = subject.getRoundDuration(Game.curRound)
	var saved_time = str(room.get("data", {}).get(subject.nextFightTimeKey, "")).split(subject.MSG_DELIMITER)
	if saved_time.size() == 2:
		default_remaining = float(saved_time[1])
	var remaining = maxf(2.0, float(room.get("local_remaining", default_remaining)))
	subject.lobbyTimer.initTimer()
	subject.lobbyTimer.updateTimer(subject.lobbyTimer.getCurTime() + remaining)
	if subject.isHost():
		subject.setLobbyData_sqn(subject.nextFightTimeKey, str(subject.lobbyTimer.getCurTime()) + subject.MSG_DELIMITER + str(remaining))

static func idToString(subject: Receiver, id: int) -> String:

	var string = ""
	id -= subject.baseValue
	if id < 0:
		string = "-"
		id = abs(id)
	for i in subject.numSymbols:
		var symbolIndex = id % subject.mod
		string = subject.symbols[symbolIndex] + string
		id = id >> subject.symbolSize

	for i in subject.numSymbols:
		string = string.trim_prefix(subject.symbols[0])

	while string.length() < 5:
		string = subject.symbols[0] + string
	return string

static func idFromString(subject: Receiver, idAsString: String):
	var id = 0
	var isNegative = false

	if idAsString.ends_with("-"):
		idAsString = idAsString.trim_suffix("-")
		isNegative = true

	var missing = subject.numSymbols - idAsString.length()
	idAsString = subject.symbols[0].repeat(missing) + idAsString

	for i in subject.numSymbols:
		var symbolIndex = subject.symbolToNumber[idAsString[i]]
		var add = symbolIndex << ((subject.numSymbols - i - 1) * subject.symbolSize)
		id += add

	if isNegative:
		id = subject.baseValue - id
	else:
		id += subject.baseValue

	return id

static func setRoundAndTimeMetadata(subject: Receiver, roundI):
	print("setting time metadata")
	var roundDur = subject.getRoundDuration(roundI)
	if roundI == 0:
		roundDur += subject.STARTGAME_COUNTDOWN
	var nextFightTime = subject.lobbyTimer.getCurTime() + roundDur
	var timeString = str(subject.lobbyTimer.getCurTime()) + subject.MSG_DELIMITER + str(roundDur)
	subject.setLobbyData_sqn(subject.nextFightTimeKey, timeString)

	subject.lobbyTimer.updateTimer(nextFightTime)

static func onOpponentQueryCompleted(subject: Receiver, handle, result, results_returned, total_matching, cached: bool):

	if handle != subject.opponentQueryHandle: return

	subject.opponentRuns.clear()

	print(Util.time, " opponent query result: ", result, ", num results: ", results_returned, " total_matching: ", total_matching)

	if results_returned > 0:
		RunDatabase.steamLeaderboard.parseMetadata(handle, results_returned,
			subject.opponentRuns, true)

	print("#parsed opponents: ", subject.opponentRuns.size())

	Steam.releaseQueryUGCRequest(handle)
	subject.opponentQueryHandle = 0

	subject.feasibleRuns.clear()
	for run in subject.opponentRuns:
		if run.getNumRounds() >= Game.curRound:
			subject.feasibleRuns.push_back(run)

	print("opponents with enough rounds: ", subject.feasibleRuns.size())

	if subject.opponentRuns.size() > 0 and subject.feasibleRuns.size() > 0:
		subject.emit_signal("found_opponent")
	else:
		print("retrying in ", subject.retryTime)
		Util.callDelayed_process(subject, "findOpponents", subject.retryTime)

static func getNextOpponentData(subject: Receiver) -> Dictionary:
	if subject.isActiveMember():
		var data: LobbyMemberData = subject.pickOpponent()
		if data == null:
			return RunDatabase.getDarkReflectionData()
		else:
			subject.opponentHistory.push_back(data.steamId)

			return RunData.createRoundDict(data.getRoundData(Game.curRound),
				data.characterClass, data.loadout, data.playerName, data.chibi,
				data.skins, Game.VERSION, false)
	else:
		return Util.pickRandomElement(subject.feasibleRuns).deserializeRound(Game.curRound)

static func onLobbyCreated(subject: Receiver, result, lobbyId):
	if result == 1:
		print("lobby created! id: ", lobbyId)
		subject.curLobbyId = lobbyId
		subject.H_hostUgcMetadata["v"] = subject.getVersionString()
		subject.H_hostUgcMetadata["lobbyId"] = str(subject.curLobbyId)
		if subject.USE_MEMBER_UGC:
			subject.createMemberUgc()
		else:
			subject.finishJoining()

		subject.setConfigDefault_Host()
	else:
		print("could not create lobby")

static func onHostUgcQueryCompleted(subject: Receiver, handle, result, results_returned, total_matching, cached: bool):

	if handle != subject.hostUgcQueryHandle: return

	print("Lobby query finished ", result)

	if result == 1 and results_returned > 0:
		var metadata = Steam.getQueryUGCMetadata(handle, 0)

		if metadata.length() < 20:
			subject.onInvalidCode()
			return

		var jsonResult = JSON.parse_string(metadata)
		if not jsonResult is Dictionary:
			subject.onInvalidCode()
			return

		for field in subject.hostUgcFields:
			if not jsonResult.has(field):
				subject.onInvalidCode()
				return

		var hostVersion = jsonResult["v"]
		if subject.getVersionString() != hostVersion:
			Util.showPopupMessage("ERROR_VersionMismatch", {"version": hostVersion})
			subject.emit_signal("join_result", subject.JoinResult.Error_VersionMismatch)
			subject.releaseQuery()
			return

		subject.partyUgcMetadata = jsonResult
		if int(subject.partyUgcMetadata["id"]) == SteamHelper.STEAM_ID:
			subject.H_hostUgcId = subject.curPartyUgcId

		if subject.partyUgcMetadata.get("started", false):

			Util.showPopupMessage("ERROR_JoinPhaseOver")
			subject.emit_signal("join_result", subject.JoinResult.Restricted_AlreadyStarted)
			subject.releaseQuery()
			return

		if subject.USE_MEMBER_UGC:
			subject.members = subject.partyUgcMetadata["members"].duplicate()

		if subject.partyState == subject.PartyState.Connecting:
			print("Lobby found!")
			if subject.USE_MEMBER_UGC:
				subject.createMemberUgc()
			else:
				subject.finishJoining()

		elif subject.partyState == subject.PartyState.Connected:
			if subject.USE_MEMBER_UGC:
				if subject.memberUgcId in subject.members:

					subject.members.erase(subject.memberUgcId)

			if subject.READ_MEMBER_UGC:
				subject.findOpponents()

	else:
		print("error when fetching party")

	subject.releaseQuery()

static func onLobbyJoined(subject: Receiver, lobbyId, _permissions, locked, response):
	print("Lobby joined ", response)

	var result
	if response == subject.LobbyJoinedResult.SUCCESS:
		result = subject.JoinResult.Unconfirmed
	elif response == subject.LobbyJoinedResult.DOESNT_EXIST:
		result = subject.JoinResult.Restricted_HostLeft
	elif (response == subject.LobbyJoinedResult.BANNED or
		response == subject.LobbyJoinedResult.COMMUNITY_BAN):
		result = subject.JoinResult.Restricted_Banned

	subject.emit_signal("join_result", result)

	if response != subject.LobbyJoinedResult.SUCCESS:
		subject.onJoinFailed()
		subject.emit_signal("lobby_join_failed")
		return

	subject.curLobbyId = lobbyId

	if subject.reconnecting:
		subject.updateOwnMetadata()
		subject.onMemberListChanged()
		if not SteamHelper.STEAM_ID in subject.memberData:

			subject.onJoinFailed()
			subject.emit_signal("lobby_join_failed")
			return

	subject.liveReconnecting = false

	subject.emit_signal("lobby_joined")

	if subject.reconnecting:
		subject.ensureTimer()
		subject.ensureScoreboard()
		subject.gameHasStarted = true
		subject.call_deferred("collectRoundData")
		subject.call_deferred("_ensure_local_guest")

		if subject.isHost():
			subject.partyState = subject.PartyState.Hosting
			subject.metadataSqn = int(subject.getLobbyData(subject.sqnKey, false))
			subject.memberMetadataSqn = int(subject.getLobbyData(subject.membersSqnKey, false))

			subject.onConfigUpdated()
			subject.onGameDataUpdated()
			subject.call_deferred("_restore_local_room_clock")
		else:
			subject.partyState = subject.PartyState.Connected

	else:

		subject.updateOwnMetadata()

		if subject.isHost():
			subject.partyState = subject.PartyState.Hosting
			print("Lobby creation 1/2")
			subject.addMember_Host(SteamHelper.STEAM_ID)
			subject.call_deferred("_ensure_local_guest")
		else:
			subject.partyState = subject.PartyState.Connected

static func resetState(subject: Receiver):
	subject.reconnecting = false
	subject.liveReconnecting = false
	subject.joinConfirmed = false
	subject.gameHasStarted = false
	subject.onResultsScreen = false
	subject.partyState = subject.PartyState.NoParty

	subject.curLobbyId = 0
	subject.hostSteamId = 0
	subject.hostUgcQueryHandle = 0
	subject.curPartyUgcId = 0
	subject.H_hostUgcId = 0

	subject.members.clear()
	subject.memberData.clear()
	subject.partyUgcMetadata.clear()
	subject.memberList.clear()
	subject.feasibleRuns.clear()
	subject.opponentHistory.clear()
	subject.H_hostUgcMetadata.clear()

	subject.metadataSqn = - 1
	subject.memberMetadataSqn = - 1
	subject.customRules = ""
	subject.matchMaking = subject.MatchMaking.Random
	subject.prioritizeHost = false
	subject.lastFightTimestamp = ""

static func onLobbyChatUpdate(subject: Receiver, lobbyId, changedId, makingChangeId, chatState):

	if Game.EDITOR:
		print("Lobby change - changedId: ", changedId, " makingChange: ", makingChangeId,
		" chatState: ", Util.enumToString(subject.ChatMemberChange, chatState))

	if subject.isMe(changedId):
		if chatState == subject.ChatMemberChange.Disconnected:

			print("trying to reconnect after disconnect")
			subject.reconnecting = true
			subject.liveReconnecting = true
			subject.partyState = subject.PartyState.Reconnecting
			subject.joinLobby(subject.curLobbyId)

	elif subject.isMemberHost(changedId):
		if chatState == subject.ChatMemberChange.Joined:

			subject.makeHostOwner()
		else:

			if not subject.gameHasStarted:
				subject.onLobbyClosed()

static func chatMessageReceived(subject: Receiver, lobbyId: int, memberId: int, buffer: String, chatType: int):

	if subject.ignoreLobbyUpdates: return
	if memberId == SteamHelper.STEAM_ID:

		return

	if chatType == subject.ChatEntryType.ChatMsg:
		var split = buffer.split(subject.MSG_DELIMITER)

		var type = int(split[0])
		print("Message type: ", Util.enumToString(subject.MessageType, type))

		match type:

			subject.MessageType.Member_Left:
				if memberId == subject.hostSteamId:
					subject.onLobbyClosed()
				elif subject.isHost():
					subject.removeMember_Host(memberId)

			subject.MessageType.Member_Reconnected:
				print(subject.memberData[memberId].playerName, " has reconnected")

			subject.MessageType.Host_GameStart:
				if subject.partyState == subject.PartyState.Connected and memberId == subject.hostSteamId:
					subject.onStartCountdown()

			subject.MessageType.Host_Kicked_Member:
				if memberId == subject.hostSteamId:
					var kickedMemberId = int(split[1])
					if subject.isMe(kickedMemberId):
						subject.onSelfKicked(int(split[2]))

static func onLobbyDataUpdate(subject: Receiver, success: int, lobbyId, memberId):
	if subject.ignoreLobbyUpdates: return

	if memberId == lobbyId:

		if subject.isClient():

			var sqn = int(subject.getLobbyData(subject.sqnKey, false))

			if sqn > subject.metadataSqn:
				subject.metadataSqn = sqn

				subject.onConfigUpdated()
				subject.onGameDataUpdated()

			var memberSqn = int(subject.getLobbyData(subject.membersSqnKey, false))
			if memberSqn > subject.memberMetadataSqn:
				subject.memberMetadataSqn = memberSqn
				subject.onMemberListChanged()

	else:

		if memberId != SteamHelper.STEAM_ID and memberId in subject.memberData:

			var data = subject.memberData.get(memberId, null)
			assert (data != null)

			var roundNum = subject.getCurRound()
			if data.getRoundData(roundNum) == null:
				var roundData: String = subject.getLobbyMemberData(memberId, str(roundNum))
				if roundData == subject.READY:
					data.setReady(true)
					subject.emit_signal("update_ready_counter")
					subject.checkAllReady()
				elif roundData == "":
					pass

				else:
					data.setReady(false)
					data.addRoundData(roundNum, roundData)
					subject.checkEnterCombat()

			var roundResults: String = subject.getLobbyMemberData(memberId, subject.resultsKey)
			if roundResults != "":
				data.setResultsFromString(roundResults)
				subject.recalculateRanking()
				subject.emit_signal("score_changed", memberId)

				if Game.curRound >= Game.MAX_ROUNDS_LOBBIES:
					if subject.allOpponentsResultsReceived():
						subject.onOpponentResultsReceived()

		if memberId == SteamHelper.STEAM_ID:

			subject.makeHostOwner()

		var info = subject.getLobbyMemberData(memberId, subject.memberInfoKey, false)
		if info != "":
			if memberId in subject.memberData:
				subject.updateMemberData(memberId, info)

			elif subject.isHost():
				var responseCode = subject.canAddMember(memberId)

				if responseCode == subject.ResponseCode.Ok:
					subject.addMember_Host(memberId)
				else:
					print("Cannot add member (", Util.enumToString(subject.ResponseCode, responseCode), ")")

					subject.sendKickMessage(memberId, responseCode)
		else:
			Util.eprint("empty info - automatic join/leave/owner change update?")

static func onMemberListChanged(subject: Receiver):
	var memberListAsString = subject.getLobbyData(subject.membersKey)
	var newMemberList_String = memberListAsString.split(subject.MSG_DELIMITER)
	var newMemberList = []
	for string in newMemberList_String:
		newMemberList.push_back(int(string))

	var newMembers = Util.subtractArr(newMemberList, subject.memberList)
	var removedMembers = Util.subtractArr(subject.memberList, newMemberList)

	for memberId in newMembers:
		subject.prepareMemberData(memberId)

	for memberId in removedMembers:
		subject.removeMember(memberId)

static func prepareMemberData(subject: Receiver, steamId: int, ugcId):

	assert ( not steamId in subject.memberList)

	print("adding ", steamId, " to member list")

	subject.memberList.push_back(steamId)
	var info: String = subject.getLobbyMemberData(steamId, subject.memberInfoKey)

	subject.updateMemberData(steamId, info, ugcId)

	print("member added successfully")
	subject.emit_signal("member_added", steamId)

	if not subject.joinConfirmed and subject.isMe(steamId):
		subject.joinConfirmed = true
		subject.emit_signal("lobby_join_confirmed")

static func updateMemberData(subject: Receiver, steamId, metadata: String, ugcId):
	var data = subject.memberData.get(steamId, null)
	if data == null:
		data = LobbyMemberData.new(steamId, ugcId)
		subject.memberData[steamId] = data

	if data.lastMetadata != metadata:
		data.lastMetadata = metadata
		var split = metadata.split(subject.MSG_DELIMITER)
		var playerName = Util.sharedBitstream.deserializeString(split[0])
		var bitStream = BitStream.new()
		bitStream.fromGodotString(split[1])
		var parsedInfo = RunData.deserializeCharacterData(bitStream, true)
		var characterClass = parsedInfo[0]
		var loadout = parsedInfo[1]
		var chibi = parsedInfo[2]
		var skins = parsedInfo[3]

		data.setData(playerName, characterClass, loadout, chibi, skins)

static func onGameDataUpdated(subject: Receiver):
	var fightTime: String = subject.getLobbyData(subject.nextFightTimeKey)
	if fightTime != "" and subject.lastFightTimestamp != fightTime:
		subject.lastFightTimestamp = fightTime

		subject.lobbyTimer.initTimer()
		var split = fightTime.split(subject.MSG_DELIMITER)
		var baseTimestamp = float(split[0])
		var roundDur = float(split[1])

		var diff = subject.lobbyTimer.getCurTime() - baseTimestamp
		print("T diff: ", diff)

		var fightTimestamp: float
		if subject.reconnecting:

			fightTimestamp = baseTimestamp + roundDur
		else:
			fightTimestamp = subject.lobbyTimer.getCurTime() + roundDur - subject.DELAY_COMPENSATION

		subject.lobbyTimer.updateTimer(fightTimestamp)

static func updateHostUgc(subject: Receiver):
	print("updating")
	subject.H_hostUgcMetadata.clear()

	subject.H_hostUgcMetadata["id"] = str(SteamHelper.STEAM_ID)
	subject.H_hostUgcMetadata["v"] = subject.getVersionString()
	subject.H_hostUgcMetadata["lobbyId"] = str(subject.curLobbyId)
	if subject.USE_MEMBER_UGC:
		subject.H_hostUgcMetadata["members"] = subject.members
	subject.H_hostUgcMetadata["started"] = subject.gameHasStarted
	var metadataString = JSON.new().stringify(subject.H_hostUgcMetadata)
	subject.ugcItem = UGCItem.new(metadataString, subject.H_hostUgcId)
	subject.ugcItem.connect("item_updated", Callable(subject, "onHostUgcUpdated"))
	subject.add_child(subject.ugcItem)
	subject.ugcItem.update()

static func collectRoundData(subject: Receiver):
	for memberId in subject.memberList:
		var data = subject.memberData.get(memberId, null)
		assert (data != null)

		var roundNum = Game.curRound

		if memberId == SteamHelper.STEAM_ID:

			var resultsAsString= subject.resultsToString()
			subject.setLobbyMemberData(subject.resultsKey, resultsAsString, false)
			data.setResultsFromString(resultsAsString)

			for roundI in range(1, min(RunDatabase.rounds.size() + 1, roundNum + 1)):
				subject.setLobbyMemberData(str(roundI), RunDatabase.rounds[roundI - 1], false)
				data.addRoundData(roundI, RunDatabase.rounds[roundI - 1])
		else:
			var roundResults: String = subject.getLobbyMemberData(memberId, subject.resultsKey, false)
			if roundResults != "":
				data.setResultsFromString(roundResults)

			for roundI in range(1, roundNum + 1):
				var roundData: String = subject.getLobbyMemberData(memberId, str(roundI), false)

				if roundData != "":
					if roundI == roundNum and roundData == subject.READY:
						data.setReady(true)
					else:

						data.addRoundData(roundI, roundData)

	print("Finished reconnect")

	subject.recalculateRanking()
	subject.emit_signal("score_changed")

	subject.checkEnterCombat()

static func pickOpponent(subject: Receiver) -> LobbyMemberData:
	if subject.getNumMembers() == 1:
		return null

	var possibleOpponents = []
	for steamId in subject.memberData:
		if steamId != SteamHelper.STEAM_ID:
			var roundData = subject.memberData[steamId].getRoundData(Game.curRound)
			if roundData != null:
				possibleOpponents.push_back(subject.memberData[steamId])

	if possibleOpponents.is_empty():
		Util.eprint("ERR: No opponents")
		return null

	if subject.getNumMembers() == 2:
		return possibleOpponents[0]

	if subject.prioritizeHost and not subject.isHost():

		var ago
		var lastMetHost = subject.opponentHistory.rfind(subject.hostSteamId)
		if lastMetHost == - 1:
			ago = subject.opponentHistory.size()
		else:
			ago = Game.curRound - (lastMetHost + 1) - 1

		if Util.flip(subject.hostRematch[ago]):
			return subject.getMemberData(subject.hostSteamId)

	var minScore: float = 1000000
	var minScoreOpponent = null

	for _oppo in possibleOpponents:
		var oppo: LobbyMemberData = _oppo
		var score = 0.0

		if subject.opponentHistory.size() >= 2:
			if (oppo.steamId == subject.opponentHistory[ - 1] and
				oppo.steamId == subject.opponentHistory[ - 2]):
				score += 100

		if subject.matchMaking == subject.MatchMaking.Random:
			var noise = [0.5]

			score += Util.rng.randf_range(0, Util.getArrayElement(noise,
				subject.getNumMembers() - 3, noise[ - 1]))
			score += subject.getRematchPenalty(oppo, subject.rematchPenalty)

		elif subject.matchMaking == subject.MatchMaking.RoundRobin:
			score += Util.rng.randf_range(0, 0.1)
			score += subject.getRematchPenalty(oppo, subject.rematchPenalty_RoundRobin)

		elif subject.matchMaking == subject.MatchMaking.EvenStats:
			score += Util.rng.randf_range(0, 0.1)
			var winDif = oppo.getWinsAtRound(Game.curRound) - Game.getNumWins()
			score += abs(winDif)
			score += subject.getRematchPenalty(oppo, subject.rematchPenalty_EvenStats)

		elif subject.matchMaking == subject.MatchMaking.Elimination:
			score += Util.rng.randf_range(0, 0.5)
			score += subject.getRematchPenalty(oppo, subject.rematchPenalty)
			if oppo.getLossesAtRound(Game.curRound) > 5:
				score += 0.5

		elif subject.matchMaking == subject.MatchMaking.Strongest:
			score += Util.rng.randf_range(0, 0.1)
			var winRate = oppo.getWinsAtRound(Game.curRound) / float(Game.curRound)
			score += winRate
			score += subject.getRematchPenalty(oppo, subject.rematchPenalty)

		if score < minScore:
			minScore = score
			minScoreOpponent = oppo

	return minScoreOpponent

static func getRematchPenalty(subject: Receiver, opponentData, penalties: Array) -> float:

	var default = Util.getArrayElement(penalties, subject.opponentHistory.size(), penalties[ - 1])
	var lastMatchRound = subject.opponentHistory.rfind(opponentData.steamId)
	if lastMatchRound == - 1:
		return default
	else:
		var ago = Game.curRound - (lastMatchRound + 1) - 1
		return Util.getArrayElement(penalties, ago, default)

static func onConfigUpdated(subject: Receiver):
	var changed = false

	var speed = int(subject.getLobbyData(subject.speedConfigKey))
	if speed != subject.lobbySpeed:
		changed = true
		subject.setSpeed(speed)

	var size = int(subject.getLobbyData(subject.sizeConfigKey))
	if size != subject.lobbySize:
		changed = true
		subject.setLobbySize(size)

	var rules = subject.getLobbyData(subject.customRulesConfigKey)
	if rules != subject.customRules:
		changed = true
		subject.setCustomRules(rules)

	var matching_encoded = int(subject.getLobbyData(subject.matchingConfigKey))
	var prioritizeH = bool(matching_encoded & subject.MatchMaking.PrioritizeHost)
	var matching = matching_encoded & ( ~ subject.MatchMaking.PrioritizeHost)
	if matching != subject.matchMaking or prioritizeH != subject.prioritizeHost:
		changed = true
		subject.setMatchMaking(matching, prioritizeH)

	if changed:
		subject.emit_signal("config_changed")

static func getRoundDuration(subject: Receiver, roundNum) -> float:
	var shopDur = subject.roundDurationCurve.sample((roundNum - 1) / 18.0)

	if roundNum == Game.SKILL_ROUND1 or roundNum == Game.SKILL_ROUND2:
		shopDur += 10
	elif roundNum == Game.SUBCLASS_ROUND:
		shopDur += 10

	var speedFactor = subject.speedFactors[subject.lobbySpeed]
	shopDur = snapped(shopDur * speedFactor, 1.0)

	if roundNum == 0:

		return shopDur
	if roundNum == Game.MAX_ROUNDS_LOBBIES:

		return subject.COMBAT_TIME + 20

	return shopDur + subject.COMBAT_TIME

static func onFightFinished(subject: Receiver, roundResult: int):
	subject._finish_local_guest_round(roundResult)
	subject._save_local_room_clock()
	if subject.isInLobby():
		var resultsAsString= subject.resultsToString()
		subject.getOwnMemberData().setResultsFromString(resultsAsString)

		subject.recalculateRanking()
		subject.emit_signal("score_changed", SteamHelper.STEAM_ID)

		subject.setLobbyMemberData(subject.resultsKey, resultsAsString)

		if Game.curRound == Game.MAX_ROUNDS_LOBBIES:
			subject.onResultsScreen = true
			subject.deleteScoreboard()

			if subject.allOpponentsResultsReceived():
				subject.onOpponentResultsReceived()

static func recalculateRanking(subject: Receiver):
	var rankedMembers = subject.memberData.values()
	rankedMembers.sort_custom(Callable(subject.MemberSorter, "sort"))

	var lastRank= 1
	var iterator= 1
	var lastScore = - 1

	for member in rankedMembers:
		var score = member.getCurrentScore()
		if score == lastScore:
			member.curRanking = lastRank
		else:
			member.curRanking = iterator
			lastRank = iterator
			lastScore = score

		iterator += 1

static func _ensure_local_guest(subject: Receiver):
	if subject.curLobbyId == 0 or not subject.isHost():
		return
	if subject.memberData.has(subject.LOCAL_GUEST_ID):
		subject.memberData[subject.LOCAL_GUEST_ID].setReady(true)
		subject.emit_signal("update_ready_counter")
		return
	LocalServices.join_room(subject.curLobbyId, subject.LOCAL_GUEST_ID)
	var bit = BitStream.new()
	RunData.serializeCharacterData(bit, true)
	var info = Util.sharedBitstream.serializeString("Local Practice Guest") + subject.MSG_DELIMITER + bit.toGodotString()
	LocalServices.member_data(subject.curLobbyId, subject.LOCAL_GUEST_ID, subject.memberInfoKey, info)
	subject.addMember_Host(subject.LOCAL_GUEST_ID)
	subject.memberData[subject.LOCAL_GUEST_ID].setReady(true)
	subject.emit_signal("update_ready_counter")

static func _finish_local_guest_round(subject: Receiver, result: int):
	if subject.memberData.has(subject.LOCAL_GUEST_ID):
		var opposite = Game.RoundResult.Loss if result == Game.RoundResult.Win else Game.RoundResult.Win
		var prior = LocalServices.member_data(subject.curLobbyId, subject.LOCAL_GUEST_ID, subject.resultsKey)
		prior += str(opposite)
		LocalServices.member_data(subject.curLobbyId, subject.LOCAL_GUEST_ID, subject.resultsKey, prior)
		subject.memberData[subject.LOCAL_GUEST_ID].setResultsFromString(prior)
		subject.memberData[subject.LOCAL_GUEST_ID].setReady(true)
