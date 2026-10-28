extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/Lobbies.gd")

static func prepareCombat(subject: Receiver):

	var curRoundMetadata = RunDatabase.serializeCurrentRound()
	subject._sync_local_guests(curRoundMetadata)
	if subject.isActiveMember():
		subject.getOwnMemberData().setReady(false)
		subject.getOwnMemberData().addRoundData(Game.curRound, curRoundMetadata)

		subject.setLobbyMemberData(str(Game.curRound), curRoundMetadata)

		subject.pushRoundToUgc()
		subject.checkEnterCombat()

static func setMemberListMetadata(subject: Receiver):
	var string = ""
	for i in subject.memberList.size():
		string += str(subject.memberList[i])
		if i != subject.memberList.size() - 1:
			string += subject.MSG_DELIMITER

	subject.setLobbyData_sqn(subject.membersKey, string, subject.membersSqnKey)

static func getPlayerMetadata(subject: Receiver) -> String:
	var data = RunDatabase.getRunDict()
	data["p"] = RunDatabase.getPlayerName()
	var steamMetaDataString = JSON.new().stringify(data)
	return steamMetaDataString

static func pushRoundToUgc(subject: Receiver):
	if not subject.USE_MEMBER_UGC: return

	print("updating ugc with round data")
	var metaDataString = subject.getPlayerMetadata()
	subject.memberUgcItem = UGCItem.new(metaDataString, subject.memberUgcId)
	subject.memberUgcItem.connect("item_updated", Callable(subject, "onUgcUpdated"))
	subject.add_child(subject.memberUgcItem)
	if subject.memberUgcId != 0:
		subject.memberUgcItem.update()

static func findOpponents(subject: Receiver):
	print("querying for opponents... ", subject.members.size())
	var matchmakingOpponents = []
	for member in subject.members:
		if member != subject.memberUgcId:
			matchmakingOpponents.push_back(member)
	subject.opponentQueryHandle = Steam.createQueryUGCDetailsRequest(matchmakingOpponents)
	Steam.setReturnMetadata(subject.opponentQueryHandle, true)
	Steam.sendQueryUGCRequest(subject.opponentQueryHandle)

static func createMemberUgc(subject: Receiver):
	var metadataString = subject.getPlayerMetadata()
	subject.ugcItem = UGCItem.new(metadataString)
	subject.ugcItem.connect("item_updated", Callable(subject, "onMemberUgcCreated"))
	subject.add_child(subject.ugcItem)

static func onMemberUgcCreated(subject: Receiver):
	print("Member ugc created!")
	subject.memberUgcId = subject.ugcItem.get_id()
	subject.ugcItem = null
	if subject.isHost():
		subject.members.push_back(subject.memberUgcId)
		subject.H_hostUgcMetadata["members"] = subject.members

	subject.finishJoining()

static func finishJoining(subject: Receiver):
	if subject.isHost():
		subject.H_hostUgcMetadata["id"] = str(SteamHelper.STEAM_ID)
		subject.createHostUgc()
	else:
		subject.joinLobby(subject.partyUgcMetadata["lobbyId"])
		subject.hostSteamId = int(subject.partyUgcMetadata["id"])

static func createHostUgc(subject: Receiver):
	var metadataStr = JSON.new().stringify(subject.H_hostUgcMetadata)

	subject.ugcItem = UGCItem.new(metadataStr)
	subject.ugcItem.connect("item_updated", Callable(subject, "onHostUgcCreated"))
	subject.ugcItem.connect("item_creation_failed", Callable(subject, "onHostUgcCreationFailed"))
	subject.add_child(subject.ugcItem)

static func onHostUgcCreated(subject: Receiver):
	subject.H_hostUgcId = subject.ugcItem.get_id()
	subject.curPartyUgcId = subject.H_hostUgcId
	subject.ugcItem = null
	subject.partyState = subject.PartyState.Hosting
	print("Lobby creation 2/2")
	subject.emit_signal("lobby_created", subject.idToString(subject.H_hostUgcId))
	subject.call_deferred("_ensure_local_guest")

static func leaveLobby(subject: Receiver):
	if not subject.isInLobby(): return

	print("Leaving Lobby.")

	if not subject.onResultsScreen:
		subject.sendLeaveMessage()

	Steam.leaveLobby(subject.curLobbyId)

	subject.ignoreLobbyUpdates = true
	subject.resetState()

	if subject.lobbyTimer != null:
		subject.lobbyTimer.disable()
		subject.lobbyTimer = null
	if subject.scoreboard != null:
		subject.deleteScoreboard()

	subject.emit_signal("lobby_left")

static func sendChatMessage(subject: Receiver, message: String):
	print("Sending msg to lobby: ", message, " type: ", Util.enumToString(subject.MessageType, int(message[0])))
	Steam.sendLobbyChatMsg(subject.curLobbyId, message)

static func makeHostOwner(subject: Receiver):
	var curOwner = Steam.getLobbyOwner(subject.curLobbyId)
	if not subject.isHost() and curOwner == SteamHelper.STEAM_ID:
		var res = Steam.setLobbyOwner(subject.curLobbyId, subject.hostSteamId)
		print("Host is owner again: ", res)

static func ensureScoreboard(subject: Receiver):
	if subject.scoreboardNode == null:
		subject.scoreboardNode = subject.scoreboardScene.instantiate()
		subject.get_tree().get_root().add_child(subject.scoreboardNode)

		subject.scoreboard = subject.scoreboardNode.get_node("Scoreboard")

		subject.scoreboardButton = subject.scoreboardNode.get_node("LobbyButton")

static func countReadyMembers(subject: Receiver) -> int:
	var ready = 0
	for member in subject.memberData:
		if subject.memberData[member].isReady():
			ready += 1
	print(ready, " members ready")
	return ready

static func getMissingOpponentNames(subject: Receiver) -> Array:
	var missing = []
	for memberId in subject.memberList:
		if subject.memberData[memberId].getRoundData(Game.curRound) == null:
			missing.push_back(subject.memberData[memberId].playerName)
	return missing

static func addMember_Host(subject: Receiver, steamId: int, memberUgcIdAsString: String):
	var ugcId = 0

	if subject.USE_MEMBER_UGC:
		if memberUgcIdAsString != "":
			ugcId = int(memberUgcIdAsString)
			if ugcId != subject.memberUgcId:
				subject.members.push_back(ugcId)
				if subject.isHost():
					print("host - adding member with id ", memberUgcIdAsString)
					subject.updateHostUgc()

	subject.prepareMemberData(steamId, ugcId)
	subject.setMemberListMetadata()

static func onSelfKicked(subject: Receiver, responseCode):
	subject.ignoreLobbyUpdates = true
	subject.emit_signal("kicked", responseCode)
	match responseCode:
		subject.ResponseCode.ManualKick:
			Util.showPopupMessage("ERROR_Kicked")
		subject.ResponseCode.AlreadyStarted:
			Util.showPopupMessage("ERROR_JoinPhaseOver")
		subject.ResponseCode.MemberLimitReached:
			Util.showPopupMessage("ERROR_MemberLimitReached")
	Game.forceLeaveLobby()

static func getLobbyData(subject: Receiver, key: String, _print: bool) -> String:
	var value = Steam.getLobbyData(subject.curLobbyId, key)
	if _print:
		print("get: ", key, " -> ", value)
	return value

static func setLobbyMemberData(subject: Receiver, key: String, value: String, _print: bool):
	if _print:
		print("set: ", SteamHelper.STEAM_ID, " key: ", key, " -> ", value)

	Steam.setLobbyMemberData(subject.curLobbyId, key, value)

static func getLobbyMemberData(subject: Receiver, playerId: int, key: String, _print: bool) -> String:
	var value = Steam.getLobbyMemberData(subject.curLobbyId, playerId, key)
	if _print:
		print("get: ", playerId, " key: ", key, " -> ", value)

	return value

static func updateOwnMetadata(subject: Receiver):
	var info = Util.sharedBitstream.serializeString(Game.getPlayerName())
	var bitStream = BitStream.new()
	RunData.serializeCharacterData(bitStream, true)
	info += subject.MSG_DELIMITER + bitStream.toGodotString()
	subject.setLobbyMemberData(subject.memberInfoKey, info)

static func createMessage(subject: Receiver, type: int, arguments):
	if arguments == null:
		return str(type)

	if typeof(arguments) == TYPE_ARRAY:
		var stringArgs = PackedStringArray(arguments)
		return str(type) + subject.MSG_DELIMITER + stringArgs.join(subject.MSG_DELIMITER)
	else:
		return str(type) + subject.MSG_DELIMITER + str(arguments)

static func countReceivedRounds(subject: Receiver, forRound):
	var num = 0
	for member in subject.memberData:
		if subject.memberData[member].getRoundData(forRound) != null:
			num += 1
	print(num, " received rounds")
	return num

static func countReceivedRoundResults(subject: Receiver, forRound):
	var num = 0
	for member in subject.memberData:
		if subject.memberData[member].getResultOfRound(forRound) != Game.RoundResult.RunOver:
			num += 1
	return num

static func setConfigDefault_Host(subject: Receiver):
	subject.setLobbyData_sqn(subject.speedConfigKey, str(subject.lobbySpeed))
	subject.setLobbyData_sqn(subject.sizeConfigKey, str(subject.lobbySize))
	subject.setLobbyData_sqn(subject.customRulesConfigKey, subject.customRules)
	subject.setLobbyData_sqn(subject.matchingConfigKey, str(subject.matchMaking))

static func setMatchMaking_Host(subject: Receiver, _matchMaking: int, _prioritizeHost):
	if subject.isInLobby():
		var encoded = _matchMaking
		if _prioritizeHost:
			encoded += subject.MatchMaking.PrioritizeHost
		subject.setLobbyData_sqn(subject.matchingConfigKey, str(encoded))
	subject.setMatchMaking(_matchMaking, _prioritizeHost)
	subject.emit_signal("config_changed")

static func tryReconnect(subject: Receiver):
	subject.reconnecting = true
	subject.partyState = subject.PartyState.Reconnecting
	var runState = Game.getRunState(Game.Mode.Lobbies)
	subject.hostSteamId = runState["hostId"]
	subject.curPartyUgcId = runState["ugcId"]
	if subject.isHost(): subject.H_hostUgcId = subject.curPartyUgcId
	subject.joinLobby(runState["lobbyId"])

static func _exit_tree(subject: Receiver):
	subject._save_local_room_clock()
	for detached_node in [subject.scoreboardNode, subject.lobbyTimer]:
		if is_instance_valid(detached_node) and detached_node.get_parent() == null:
			detached_node.free()

## Local guest records let room UI and room combat work on a single machine.

static func _sync_local_guests(subject: Receiver, round_metadata: String):
	for member_id in subject.memberList:
		if member_id == subject.LOCAL_GUEST_ID:
			subject.memberData[member_id].addRoundData(Game.curRound, round_metadata)
			subject.memberData[member_id].setReady(true)
			LocalServices.member_data(subject.curLobbyId, member_id, str(Game.curRound), round_metadata)
