extends Node
signal scores_received(scores)
signal position_received(position)
signal score_posted
signal sw_scores_received(board, scores)
signal sw_player_scores_received(scores)
signal sw_top_player_score_received(score)
signal sw_position_received(position)
signal sw_scores_around_received(above, below, position)
signal sw_score_posted(id)
signal sw_leaderboard_wiped
signal sw_score_deleted
var leaderboards = {}
var leaderboards_past_periods = {}
var ldboard_config = {}
var scores = []
var player_scores = []
var player_top_score = null
var local_scores = []
var score_id = ""
var position = 0
var scores_above = []
var scores_below = []
var latest_max = 10
func _store():
	return get_node("/root/LocalServices")
func _later(signal_name, arguments = []):
	call_deferred("_deliver", signal_name, arguments)
	return self
func _deliver(signal_name, arguments):
	callv("emit_signal", [signal_name] + arguments)
func get_high_scores(maximum = 10, board = "main", _period_offset = 0):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalScoresBehavior.gd").get_high_scores(self, maximum, board, _period_offset)

func get_scores_by_player(player_name, maximum = 10, board = "main", _period_offset = 0):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalScoresBehavior.gd").get_scores_by_player(self, player_name, maximum, board, _period_offset)

func get_top_score_by_player(player_name, maximum = 10, board = "main", period_offset = 0):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalScoresBehavior.gd").get_top_score_by_player(self, player_name, maximum, board, period_offset)

func add_to_local_scores(result, board = "main"):
	local_scores.append(result)
	leaderboards[board] = local_scores
func persist_score(player_name, value, board = "main", metadata = {}):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalScoresBehavior.gd").persist_score(self, player_name, value, board, metadata)

func get_score_position(value, board = "main"):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalScoresBehavior.gd").get_score_position(self, value, board)

func get_scores_around(value, maximum = 3, board = "main"):
	return load("res://Runtime/Behavior/LocalServices/LocalScoresBehavior.gd").get_scores_around(self, value, maximum, board)

func delete_score(id):
	_store().delete_score(str(id))
	return _later("sw_score_deleted")
func wipe_leaderboard(board = "main"):
	_store().clear_board(str(board))
	return _later("sw_leaderboard_wiped")
