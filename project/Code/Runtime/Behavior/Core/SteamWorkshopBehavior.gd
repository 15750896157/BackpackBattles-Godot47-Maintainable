extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Code/Core/SteamWorkshop.gd")

static func _read_local_board(subject: Receiver) -> void:
	var rows: Array = subject._store().scores(subject._db().getLeaderboard())
	subject.parsedRuns = subject._db().parseScores(rows)
	for row in rows:
		subject.largestSequenceNumber = maxi(subject.largestSequenceNumber, int(row.get("score", 0)) + 1)
	subject.gotResponse = true
	subject.finalize()
