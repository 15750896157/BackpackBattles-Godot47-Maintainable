extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/RunData.gd")

static func serialize(subject: Receiver):
	var data = [
		subject.runId,
		subject.encodedName,
		subject.rating,
		subject.playerId,
		subject.results,
		subject.characterClass,
		subject.rounds,
		subject.entryVersion,
		subject.chibiStyle,
		subject.skins.duplicate()]
	if data.size() != subject.NUM_PROPERTIES:
		print("!! serialization failed")
	return data

static func checkVersion(subject: Receiver):
	if not Util.laterOrEqual(subject.entryVersion, Game.leaderboardBreakingVersion):
		return subject.DeserializeResult.VERSION_TOO_OLD
	if Util.later(subject.entryVersion, Game.VERSION):
		return subject.DeserializeResult.VERSION_TOO_NEW
	else:
		return subject.DeserializeResult.VERSION_OK

static func isAvailableForClassOrAppropriated(subject: Receiver, descriptor, itemCounter) -> bool:
	if descriptor.isAvailableFor(subject.characterClass):
		return true
	else:

		for item in descriptor.appropriatingItems:
			if itemCounter[item.itemIndex] != 0:
				return true
	return false

static func fromSilentWolfScore(subject: Receiver, score: Dictionary):
	for field in subject.swFields:
		if not field in score.metadata:
			Util.eprint("no field ", field)
			return subject.DeserializeResult.VERSION_TOO_OLD

	subject.runId = score.score_id
	return subject.fromData(score.player_name, score.metadata)

static func fromSteamScore(subject: Receiver, dict: Dictionary, lobbyMode: bool):
	if not lobbyMode:
		for field in subject.steamFields:
			if not field in dict:
				Util.eprint("no field ", field)
				return subject.DeserializeResult.VERSION_TOO_OLD

	subject.runId = dict["ugc"]
	return subject.fromData(dict["p"], dict, lobbyMode)
