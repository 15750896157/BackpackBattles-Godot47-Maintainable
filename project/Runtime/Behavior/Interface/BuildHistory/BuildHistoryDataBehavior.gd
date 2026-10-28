extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/BuildHistory/BuildHistoryData.gd")

static func getSurvivalStartRound(subject: Receiver) -> int:
	var numWins = 0
	var survivalStartRound = - 1
	for roundI in subject.roundHistory.size():
		if subject.roundHistory[roundI] != null and subject.roundHistory[roundI].result == Game.RoundResult.Win:
			numWins += 1
			if numWins == Game.MAX_WINS:
				survivalStartRound = roundI

	if subject.roundHistory.size() > survivalStartRound:
		return survivalStartRound
	else:
		return - 1
