extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/RunDatabase.gd")

static func parseScores(subject: Receiver, scores):
	var newRuns = []

	var largestSequenceNumber = 0
	for score in scores:
		if score.score > largestSequenceNumber:
			largestSequenceNumber = score.score
		var runData = subject.parseSingleScore(score, false)
		if runData:
			newRuns.push_back(runData)

	subject.swSequenceNumber = max(subject.swSequenceNumber, largestSequenceNumber + 1)
	return newRuns

static func checkSteamRunsReceived(subject: Receiver):

	if subject.silentwolfRuns.is_empty() and subject.steamLeaderboard.parsedRuns.is_empty():
		print("Steam timeout. requesting sw")
		if not subject.statisticsMode:
			SilentWolf.Scores.get_high_scores(400, subject.getLeaderboard())

static func _normalize_local_practice(subject: Receiver, round_data: Dictionary, run) -> Dictionary:
	if run.get_meta("local_source", "") == "locally_generated_practice":
		round_data["health"] = Game.getMaxHealthInRound(run.characterClass, Game.curRound)
	return round_data

static func getRoundData(subject: Receiver, roundNum):
	if subject.rounds.size() < roundNum and Game.EDITOR:
		return subject.rounds[min(roundNum, subject.rounds.size() - 1)]
	return subject.rounds[roundNum]

static func pushRun(subject: Receiver):

	if not Game.canCommitRun:
		return

	if subject.facedNoConnectionDarkReflection > 0 and not Game.BETA:
		return

	var data = subject.getRunDict()
	var playerName = subject.getPlayerName()

	Util.callNextFrame(subject, "actuallyPersistRun", [playerName, data])

static func getPlayerName(subject: Receiver) -> String:
	var playerName = Game.getPlayerName()
	if not Profanity.isGood(playerName):
		playerName = Util.pickRandomElement(subject.replaceNames)

	playerName = Util.sharedBitstream.serializeString(playerName)
	return playerName

static func actuallyPersistRun(subject: Receiver, playerName, data: Dictionary):
	var sequence = maxi(subject.swSequenceNumber, LocalServices.stat("local_run_sequence") + 1)
	LocalServices.set_stat("local_run_sequence", sequence)
	LocalServices.persist_score(subject.getLeaderboard(), playerName, sequence, data, "player_recorded")
	subject.swSequenceNumber = sequence + 1
	subject.sendRunRequest()
