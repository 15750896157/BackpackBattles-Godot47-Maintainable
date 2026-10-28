extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/SteamWorkshop.gd")

static func parseMetadata(subject: Receiver, handle: int, results_returned: int, runArr: Array, lobbyMode: bool) -> void:
	var steam = subject.get_node("/root/Steam")
	for index in results_returned:
		var value = JSON.parse_string(steam.getQueryUGCMetadata(handle, index))
		if value is Dictionary:
			var run = subject._db().parseSingleScore(value, true, lobbyMode)
			if run != null: runArr.append(run)

static func _read_local_board(subject: Receiver) -> void:
	var rows: Array = subject._store().scores(subject._db().getLeaderboard())
	subject.parsedRuns = subject._db().parseScores(rows)
	for row in rows:
		subject.largestSequenceNumber = maxi(subject.largestSequenceNumber, int(row.get("score", 0)) + 1)
	subject.gotResponse = true
	subject.finalize()

static func pushScore(subject: Receiver, metadata_text: String, sequence: int) -> void:
	var metadata = JSON.parse_string(metadata_text)
	if metadata is Dictionary:
		subject._store().persist_score(subject._db().getLeaderboard(), str(metadata.get("p", "Local Player")), sequence, metadata)
		subject.downloadScores()
