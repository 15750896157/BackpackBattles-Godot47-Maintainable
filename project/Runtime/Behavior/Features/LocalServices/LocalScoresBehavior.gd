extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalScores.gd")

static func get_high_scores(subject: Receiver, maximum, board, _period_offset):
	subject.scores = subject._store().scores(str(board), 2000 if int(maximum) <= 0 else int(maximum))
	subject.leaderboards[board] = subject.scores
	subject._later("scores_received", [subject.scores])
	return subject._later("sw_scores_received", [board, subject.scores])

static func get_scores_by_player(subject: Receiver, player_name, maximum, board, _period_offset):
	subject.player_scores = subject._store().scores(str(board), 2000).filter(func(row): return row.player_name == player_name).slice(0, 2000 if int(maximum) <= 0 else int(maximum))
	return subject._later("sw_player_scores_received", [subject.player_scores])

static func get_top_score_by_player(subject: Receiver, player_name, maximum, board, period_offset):
	subject.get_scores_by_player(player_name, maximum, board, period_offset)
	subject.player_top_score = null if subject.player_scores.is_empty() else subject.player_scores[0]
	return subject._later("sw_top_player_score_received", [subject.player_top_score])

static func persist_score(subject: Receiver, player_name, value, board, metadata):
	var row = subject._store().persist_score(str(board), str(player_name), float(value), metadata)
	subject.score_id = str(row.score_id)
	subject._later("score_posted")
	return subject._later("sw_score_posted", [subject.score_id])

static func get_score_position(subject: Receiver, value, board):
	subject.position = 1
	for row in subject._store().scores(str(board), 2000):
		if float(row.score) > float(value): subject.position += 1
	subject._later("position_received", [subject.position])
	return subject._later("sw_position_received", [subject.position])
