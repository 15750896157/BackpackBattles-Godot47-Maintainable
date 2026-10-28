extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/BuildHistoryDB.gd")

static func addRunEntry(subject: Receiver):
	var rank: float = -1.0
	if Game.curMode == Game.Mode.Ranked:
		rank = Game.getRunRating(Game.curClass)
	elif Game.isRankedSwitchMode():
		rank = Game.getSwitchModeRating()
	elif Game.curMode == Game.Mode.Lobbies:
		rank = -2.0
	var loadout = Game.Loadout.RandomCharacter if Game.randomCharacter else Game.curLoadout
	var row = {"version": Game.versionToInt(), "class": Game.curClass,
		"loadout": loadout, "rank": rank, "runID": Game.getNumStartedRuns(),
		"time": int(Time.get_unix_time_from_system()), "custom": CustomRules.serialize(),
		"subclass": null, "skill1": null, "skill2": null}
	if not subject._report_storage_result(subject.db.write_run(row)):
		return false
	return subject.cleanup()

static func onSpecialItemBought(subject: Receiver, item):
	if item == null or item.descriptor == null:
		return false
	var fields: Dictionary = {}
	if Game.curRound == Game.SUBCLASS_ROUND:
		fields["subclass"] = item.descriptor.itemIndex
	elif Game.curRound == Game.SKILL_ROUND1:
		fields["skill1"] = item.descriptor.itemIndex
	elif Game.curRound == Game.SKILL_ROUND2:
		fields["skill2"] = item.descriptor.itemIndex
	if fields.is_empty():
		return true
	return subject._report_storage_result(subject.db.update_run(int(Game.getRunState()["id"]), fields))

static func addRoundEntry(subject: Receiver):
	var round_index = Game.curRound - 2
	if round_index < 0 or round_index >= Game.roundResults.size() or Game.PLAYER == null:
		subject.last_error = "The round result is not ready to be recorded."
		return false
	var row = {"roundID": Game.curRound - 1, "result": Game.roundResults[round_index],
		"tries": Game.getTries(), "health": int(Game.PLAYER.getBaseMaxHealth()),
		"stamina": int(Game.PLAYER.getBaseMaxStamina()),
		"buildInfo": RunDatabase.getRoundData(round_index), "runID": int(Game.getRunState()["id"])}
	return subject._report_storage_result(subject.db.write_round(row))

static func readRunHistory(subject: Receiver) -> Dictionary:
	var runs: Dictionary = {}
	for row in subject.db.read_runs():
		var data = BuildHistoryData.new()
		data.version = int(row.version)
		data.time = int(row.time)
		data.customRules = row.custom
		data.classI = int(row["class"])
		data.loadout = int(row.loadout)
		data.id = int(row.runID)
		data.subclassIndex = row.subclass
		data.skill1Index = row.skill1
		data.skill2Index = row.skill2
		if row.rank == -1.0:
			data.mode = Game.Mode.Unranked
		elif row.rank == -2.0:
			data.mode = Game.Mode.Lobbies
		else:
			data.mode = Game.Mode.Ranked
			data.rating = float(row.rank)
		runs[data.id] = data
	for row in subject.db.read_rounds():
		var data = runs.get(int(row.runID))
		if data != null:
			data.addRoundData(int(row.roundID), int(row.result), int(row.tries),
				int(row.health), int(row.stamina), row.buildInfo)
	return runs
