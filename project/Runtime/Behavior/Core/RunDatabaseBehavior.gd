extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/RunDatabase.gd")

static func _ready(subject: Receiver) -> void:
	subject.process_mode = Node.PROCESS_MODE_ALWAYS
	SilentWolf.configure({"game_id": "bpb-local", "game_version": Game.VERSION, "log_level": 0, "local": true})
	SilentWolf.Scores.sw_scores_received.connect(subject.onSilentwolfRunsReceived)
	Game.fresh_run_started.connect(subject._seed_local_opponents)
	subject.call_deferred("ready_deferred")

static func ready_deferred(subject: Receiver):
	subject.resendTimer = Timer.new()
	subject.resendTimer.wait_time = 300.0
	subject.resendTimer.timeout.connect(subject.sendRunRequest)
	subject.add_child(subject.resendTimer)
	subject.steamLeaderboard = load("res://Core/SteamWorkshop.gd").new()
	subject.add_child(subject.steamLeaderboard)
	if Game.LOBBIES_ENABLED:
		subject.lobbies = load("res://Utility/Lobbies.gd").new()
		subject.add_child(subject.lobbies)
	Game.connectingLabel.hide()
	subject.get_tree().create_timer(1.5).timeout.connect(subject._seed_local_opponents)
	subject.sendRunRequest()

static func parseSingleScore(subject: Receiver, score, steam: bool, lobbyMode: bool):
	var runData = RunData.new()
	var metadata: Dictionary = score if steam else score.get("metadata", {})
	if metadata.has("_local_serialized"):
		if runData.fromSerialized(metadata["_local_serialized"]) == 0:
			runData.loadout = int(metadata.get("_local_loadout", 0))
			runData.set_meta("local_source", score.get("source", "player_recorded"))
			if runData.get_meta("local_source") == "locally_generated_practice" and runData.playerId.begins_with("local_practice_"):
				var practice_number = int(runData.playerId.trim_prefix("local_practice_")) + 1
				runData.encodedName = Util.sharedBitstream.serializeString("Local Practice%02d" % practice_number)
			return runData
		return null
	var result = runData.fromSteamScore(score, lobbyMode) if steam else runData.fromSilentWolfScore(score)
	return runData if result == RunData.DeserializeResult.VERSION_OK else null

static func onSteamRunsReceived(subject: Receiver):
	print("received Steam: ", subject.steamLeaderboard.parsedRuns.size())
	if subject.steamLeaderboard.parsedRuns.size() > 0:
		if (subject.steamLeaderboard.parsedRuns.size() >= subject.MIN_CACHE_ENTRIES or
			subject.runsFromCache.size() < subject.MIN_CACHE_ENTRIES):
			subject.cacheRuns(subject.steamLeaderboard.parsedRuns, true)
		subject.onRunsReceived()

	# Local cumulative records belong to ProfileService, not the removed remote statistics viewer.

static func getNextOpponentData(subject: Receiver, roundReduction: int) -> Dictionary:

	if Game.curMode == Game.Mode.Lobbies:
		return subject.lobbies.getNextOpponentData()

	if subject.faceDarkReflection:

		return subject.getDarkReflectionData()

	var opponentRun = null

	for i in range(subject.curOpponentIndex, subject.feasibleRuns.size()):
		subject.curOpponentIndex += 1
		var run = subject.feasibleRuns[i]
		if run.get_meta("local_source", "") == "locally_generated_practice" and run.deserializeRound(Game.curRound) == null:
			continue
		var validity = RunData.Validity.Ok if run.get_meta("local_source", "") == "locally_generated_practice" else run.isValid(Game.curRound)
		if (validity == RunData.Validity.Ok or
			(validity == RunData.Validity.TooManyUniques
				and subject.feasibleRuns.size() < 100)):
			opponentRun = run
			break

	if not opponentRun:
		return subject.getDarkReflectionData()
	else:
		subject.recentOpponentRuns.push_back(opponentRun)
		subject.recentOpponentNames.push_back(opponentRun.encodedName)

		if roundReduction > 0:
			var curRound = opponentRun.deserializeRound(Game.curRound)
			var previousRound = opponentRun.deserializeRound(Game.curRound - roundReduction)
			if previousRound:
				curRound["items"] = previousRound["items"]

			return subject._normalize_local_practice(curRound, opponentRun)
		else:

			return subject._normalize_local_practice(opponentRun.deserializeRound(Game.curRound), opponentRun)

static func getDarkReflectionData(subject: Receiver) -> Dictionary:
	var roundData = RunData.deserializeStream(subject.getFallbackOpponent(), Game.VERSION)
	roundData["class"] = Game.PLAYER.getClass()
	roundData["name"] = subject.tr("OPPONENT_PLACEHOLDER")
	roundData["chibi"] = Game.getEffectiveChibiMode()
	var skins = []
	for slot in Game.SkinSlot.size():
		skins.push_back(Game.getSelectedSkin(slot))
	roundData["skins"] = skins
	roundData["reflection"] = true
	return roundData

static func sortOpponents(subject: Receiver):
	var encodedPlayerName = Util.sharedBitstream.serializeString(Game.getPlayerName())
	subject.feasibleRuns.clear()
	subject.curOpponentIndex = 0

	var curRating= 0
	var weAreUnranked= false

	if Game.curMode == Game.Mode.Unranked:
		if CustomRules.isRankedSwitchMode():
			curRating = Game.getSwitchModeRating()
			weAreUnranked = false
		else:
			var overrideLeague = CustomRules.getLeagueToMatch()
			if overrideLeague == CustomRules.UNRANKED:
				weAreUnranked = true
			else:
				weAreUnranked = false
				curRating = (Game.leagueThresholds[overrideLeague] + Game.leagueThresholds[overrideLeague + 1]) * 0.5

	elif Game.curMode == Game.Mode.Ranked:
		weAreUnranked = false
		curRating = Game.getRunRating(Game.curClass)

	elif Game.curMode == Game.Mode.History:
		if Game.curHistoryData.mode == Game.Mode.Ranked:
			weAreUnranked = false
			curRating = Game.curHistoryData.rating
		elif Game.curHistoryData.mode == Game.Mode.Lobbies:
			weAreUnranked = true
		else:
			var overrideLeague = CustomRules.getLeagueToMatch()
			if overrideLeague == CustomRules.UNRANKED:
				weAreUnranked = true
			else:
				weAreUnranked = false

				curRating = (Game.leagueThresholds[overrideLeague] + Game.leagueThresholds[overrideLeague + 1]) * 0.5

	var playerResults = Game.getRoundResults()

	for run in subject.getParsedRuns():
		if run.getNumRounds() >= Game.curRound:
			subject.feasibleRuns.push_back(run)

	subject.feasibleRuns.shuffle()

	var classCounter
	var maxClasses
	var minClasses
	var inspectClasses = true

	if Game.curMode == Game.Mode.Unranked:
		inspectClasses = Util.flip(0.5)
	else:
		inspectClasses = Util.flip(0.8)

	if Game.FULLVERSION and inspectClasses:
		classCounter = [0, 0, 0, 0, 0, 0, 0]
		for run in subject.recentOpponentRuns:
			classCounter[run.characterClass] += 1

		minClasses = Util.findAll(classCounter, classCounter.min())
		maxClasses = Util.findAll(classCounter, classCounter.max())

	var recentOpponentNamesDict = Dictionary()
	for i in subject.recentOpponentNames.size():
		recentOpponentNamesDict[subject.recentOpponentNames[i]] = i

	var targetWins = playerResults[Game.RoundResult.Win]

	if Game.isBelowLeague(Game.Leagues.Master):
		if Util.rng.randf() < 0.5:
			targetWins = max(targetWins - 1, 0)

	for run in subject.feasibleRuns:
		run.mmScore = 0.0

		if run.playerId == Game.getPlayerIdentifier():
			run.mmScore += 10000

		elif run.encodedName == encodedPlayerName:
			run.mmScore += 5000

		var theyAreUnranked = run.rating == subject.UNRANKED_RATING
		if weAreUnranked != theyAreUnranked:
			run.mmScore += 1000

		var rematchMalus = 0

		var matchedBeforeRound = recentOpponentNamesDict.get(run.encodedName, - 1)
		if matchedBeforeRound != - 1:
			var lastEncounter = subject.recentOpponentNames.size() - matchedBeforeRound
			if lastEncounter <= subject.rematchSameOpponentTimeout:
				if lastEncounter < 5:
					rematchMalus += 1100
				else:
					rematchMalus += 131
				rematchMalus += (subject.rematchSameOpponentTimeout - lastEncounter)

			elif lastEncounter <= subject.rematchSameOpponentTimeout + 10:
				rematchMalus += 0.2
			elif lastEncounter <= subject.rematchSameOpponentTimeout + 20:
				rematchMalus += 0.1

		run.mmScore += rematchMalus

		if Game.FULLVERSION and inspectClasses:
			if run.characterClass in minClasses:
				run.mmScore -= 0.1

			if run.characterClass in maxClasses:
				run.mmScore += 0.1

			if ( not subject.recentOpponentRuns.is_empty() and
				subject.recentOpponentRuns[ - 1].characterClass == run.characterClass):
				run.mmScore += 0.2

				if (subject.recentOpponentRuns.size() >= 2 and
					subject.recentOpponentRuns[ - 2].characterClass == run.characterClass):
					run.mmScore += 22

		var theirWins = run.getWinsAtRound(Game.curRound - 1)
		var winDif = theirWins - targetWins
		if winDif > 0:
			run.mmScore += 10 * winDif
		else:
			run.mmScore += 5 * abs(winDif)

		if theirWins == Game.MAX_WINS:
			run.mmScore += 1000

		if not theyAreUnranked:
			var rankDiff = abs(curRating - run.rating)
			run.mmScore += clamp(rankDiff / 1000.0, 0, 1)
			if rankDiff > 150:
				run.mmScore += 12

		run.mmScore += Util.rng.randf_range(0, 0.05)

	subject.feasibleRuns.sort_custom(Callable(subject.Matchmaker, "sort_ascending"))

static func serializeRound(subject: Receiver) -> String:
	var bitStream = BitStream.new()

	bitStream.push(Game.PLAYER.getBaseMaxHealth(), Game.MAX_HEALTH)
	bitStream.push(Game.PLAYER.getMaxBaseStamina(), Game.MAX_STAMINA)

	var totalNumItems: int

	if Util.laterOrEqual(Game.VERSION, "1.1.0"):
		totalNumItems = ItemBook.getNumItems()
	else:
		totalNumItems = 510

	for item in Game.PLAYER.INVENTORY.getItems():
		bitStream.push(ItemBook.getItemIndex(item), totalNumItems)
		var topLeft = item.getTopLeftCell()
		bitStream.push(topLeft.x, Game.PLAYER.INVENTORY.MAX_SIZE.x)
		bitStream.push(topLeft.y, Game.PLAYER.INVENTORY.MAX_SIZE.y)
		bitStream.push(item.getFaceDirection(), 4)

		if item.hasSockets():
			if item.hasGems():
				bitStream.pushBit(true)
				var gems = item.getGems()
				for gem in gems:
					if gem:
						bitStream.push(ItemBook.getGemIndex(gem), subject.totalNumGems)
					else:
						bitStream.push(subject.emptySocketId, subject.totalNumGems)
			else:
				bitStream.pushBit(false)

		if item.has_method("getDataPersistent"):
			item.getDataPersistent(bitStream)

	return bitStream.toGodotString()

static func serializeMetadata(subject: Receiver) -> BitStream:
	var bitStream = BitStream.new()
	var versionSplit = Game.VERSION.split(".")
	bitStream.push(int(versionSplit[0]), 4)
	bitStream.push(int(versionSplit[1]), 16)
	bitStream.push(int(versionSplit[2]), 64)

	for result in Game.roundResults:
		bitStream.push(result, Game.RoundResult.size())

	RunData.serializeCharacterData(bitStream, Game.FULLVERSION)

	return bitStream

static func getRunDict(subject: Receiver) -> Dictionary:
	var data = Dictionary()
	data[RunData.VERSION_FIELD] = subject.serializeMetadata().toGodotString()

	var rating = Game.getRunRating(Game.curClass)
	if Game.curMode == Game.Mode.Ranked:
		data["r"] = rating
	else:
		data["r"] = subject.UNRANKED_RATING

	data["id"] = Game.getPlayerIdentifier()

	var roundIndex = 0
	for r in subject.rounds:
		data[str(roundIndex)] = r
		roundIndex += 1

	return data

static func _seed_local_opponents(subject: Receiver):
	if not is_instance_valid(Game.PLAYER):
		subject.get_tree().create_timer(1.0).timeout.connect(subject._seed_local_opponents)
		return
	if LocalServices.scores(subject.getLeaderboard()).is_empty():
		var starting_round = subject.serializeRound()
		for index in range(32):
			var run = subject._make_local_run("Local Practice%02d" % (index + 1), "local_practice_" + str(index))
			run.rating = subject.UNRANKED_RATING if index % 2 == 0 else Game.getRunRating(Game.curClass)
			run.results.resize(Game.getMaxNumberOfRounds())
			for result_index in run.results.size():
				run.results[result_index] = Game.RoundResult.Win if (index + result_index) % 3 != 0 else Game.RoundResult.Loss
			run.rounds.clear()
			for _round_index in Game.getMaxNumberOfRounds(): run.rounds.append(starting_round)
			LocalServices.persist_score(subject.getLeaderboard(), run.encodedName, index + 1, {"_local_serialized": run.serialize(), "_local_loadout": run.loadout}, "locally_generated_practice")
	subject.sendRunRequest()

static func _make_local_run(subject: Receiver, player_name: String, player_id: String):
	var run = RunData.new()
	run.runId = str(LocalServices.next_id())
	run.encodedName = Util.sharedBitstream.serializeString(player_name)
	run.rating = subject.UNRANKED_RATING if Game.curMode != Game.Mode.Ranked else Game.getRunRating(Game.curClass)
	run.playerId = player_id
	run.results = Game.roundResults.duplicate()
	if run.results.is_empty():
		run.results.resize(Game.getMaxNumberOfRounds())
		run.results.fill(Game.RoundResult.Win)
	run.characterClass = Game.curClass
	run.loadout = Game.curLoadout
	run.rounds = subject.rounds.duplicate()
	run.entryVersion = Game.VERSION
	run.chibiStyle = Game.getEffectiveChibiMode()
	for slot in Game.SkinSlot.size(): run.skins.append(Game.getSelectedSkin(slot))
	return run

static func _record_local_snapshot(subject: Receiver, source: String):
	var run = subject._make_local_run(Game.getPlayerName(), str(Game.getPlayerIdentifier()))
	LocalServices.set_profile_name(Game.getPlayerName())
	var sequence = maxi(subject.swSequenceNumber, LocalServices.stat("local_run_sequence") + 1)
	LocalServices.set_stat("local_run_sequence", sequence)
	LocalServices.persist_score(subject.getLeaderboard(), run.encodedName, sequence, {"_local_serialized": run.serialize(), "_local_loadout": run.loadout}, source)
	subject.swSequenceNumber = sequence + 1
	subject.sendRunRequest()
