extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/BuildHistory/BuildHistoryData.gd")

static func addRoundData(subject: Receiver, roundNum: int, result: int, tries: int, health: int, stamina: int, items: String):
	if roundNum <= 0:
		return

	var roundData = subject.RoundData.new()
	roundData.result = result
	roundData.tries = tries
	roundData.health = health
	roundData.stamina = stamina
	roundData.items = items

	if subject.roundHistory.size() < roundNum:
		subject.roundHistory.resize(roundNum)

	subject.roundHistory[roundNum - 1] = roundData

static func getWins(subject: Receiver, upToRound: int) -> int:
	if upToRound < 0:
		upToRound = subject.getRounds()
	var wins = 0
	for roundI in min(upToRound, subject.roundHistory.size()):
		if subject.roundHistory[roundI] != null and subject.roundHistory[roundI].result == Game.RoundResult.Win:
			wins += 1
	return wins

static func getLosses(subject: Receiver, upToRound: int) -> int:
	if upToRound < 0:
		upToRound = subject.getRounds()
	var losses = 0
	for roundI in min(upToRound, subject.roundHistory.size()):
		if subject.roundHistory[roundI] != null and subject.roundHistory[roundI].result == Game.RoundResult.Loss:
			losses += 1
	return losses

static func getTries(subject: Receiver, atRound: int) -> int:
	if atRound < 0:
		atRound = subject.getRounds()
	if subject.roundHistory.is_empty() or subject.getRoundData(atRound) == null:
		return Game.MAX_TRIES
	else:
		return subject.roundHistory[atRound - 1].tries

static func getTimeDif(subject: Receiver) -> Dictionary:
	var timeDif = maxi(0, int(Time.get_unix_time_from_system()) - subject.time)
	var dict = Time.get_time_dict_from_unix_time(timeDif)
	dict["days"] = int(timeDif / (60 * 60 * 24))
	return dict
