extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/LobbyMemberData.gd")

static func setResultsFromString(subject: Receiver, results: String):

	subject.fightsFinished = 0
	var tries = Game.MAX_TRIES_LOBBIES

	for roundI in results.length():
		var result = int(results[roundI])
		subject.roundResults[roundI] = result

		if result != Game.RoundResult.RunOver:
			subject.fightsFinished += 1

			if result == Game.RoundResult.Win:
				subject.triesLeft[roundI] = tries
			elif result == Game.RoundResult.Loss:
				subject.triesLeft[roundI] = max(0, tries - 1)
			else:
				subject.triesLeft[roundI] = tries
			tries = subject.triesLeft[roundI]
