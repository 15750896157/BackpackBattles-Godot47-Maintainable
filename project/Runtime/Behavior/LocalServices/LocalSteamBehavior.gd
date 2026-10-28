extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalSteam.gd")

static func downloadLeaderboardEntries(subject: Receiver, _start, maximum, _type, handle: int) -> void:
	var entries = []
	for row in subject._store().scores(str(subject._handles.get(handle, "main")), int(maximum)):
		entries.append({"score": row.score, "details": PackedInt32Array([0, 0]), "local_record": row})
	subject._later("leaderboard_scores_downloaded", ["Local file board", handle, entries])

static func uploadLeaderboardScore(subject: Receiver, score, _keep_best, details, handle: int) -> bool:
	var metadata = {}
	if details.size() >= 2:
		var id = (int(details[0]) & 0xffffffff) | (int(details[1]) << 32)
		var text = subject._store().workshop.get(str(id), {}).get("metadata", "")
		var decoded = JSON.parse_string(text)
		if decoded is Dictionary:
			metadata = decoded
	var row = subject._store().persist_score(str(subject._handles.get(handle, "main")), subject.getPersonaName(), float(score), metadata)
	subject._later("leaderboard_score_uploaded", [1, handle, row])
	return true

static func getQueryUGCMetadata(subject: Receiver, handle: int, index: int) -> String:
	var ids: Array = subject._queries.get(handle, [])
	if index < 0 or index >= ids.size():
		return ""
	return str(subject._store().workshop.get(str(int(ids[index])), {}).get("metadata", ""))
