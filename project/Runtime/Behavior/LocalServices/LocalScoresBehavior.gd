extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalScores.gd")

static func get_scores_around(subject: Receiver, value, maximum, board):
	subject.get_score_position(value, board)
	var rows = subject._store().scores(str(board), 2000)
	subject.scores_above = rows.slice(maxi(0, subject.position - int(maximum) - 1), subject.position - 1)
	subject.scores_below = rows.slice(subject.position, subject.position + int(maximum))
	return subject._later("sw_scores_around_received", [subject.scores_above, subject.scores_below, subject.position])
