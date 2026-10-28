extends Node
## SilentWolf-compatible local file facade. No remote API configuration is used.
signal sw_ready
const version = "local-1.0"
var godot_version = Engine.get_version_info().string
var config = {"local": true, "game_id": "bpb-local", "game_version": "1.1.8", "log_level": 0}
var auth_config = {"redirect_to_scene": "", "session_duration_seconds": 0}
var scores_config = {"open_scene_on_close": ""}
var Auth
var Scores
var Players
var Multiplayer
func _ready():
	Auth = load("res://LocalServices/LocalAuth.gd").new()
	Scores = load("res://LocalServices/LocalScores.gd").new()
	Players = load("res://LocalServices/LocalPlayers.gd").new()
	Multiplayer = load("res://LocalServices/LocalMultiplayer.gd").new()
	for pair in [[Auth,"Auth"], [Scores,"Scores"], [Players,"Players"], [Multiplayer,"Multiplayer"]]:
		pair[0].name = pair[1]
		add_child(pair[0])
	sw_ready.emit()
func configure(value):
	config.merge(value, true)
	config.erase("api_key")
	config["local"] = true
func configure_api_key(_ignored):
	pass
func configure_game_id(value):
	config["game_id"] = value
func configure_game_version(value):
	config["game_version"] = value
func configure_scores(value):
	scores_config = value
func configure_scores_open_scene_on_close(value):
	scores_config["open_scene_on_close"] = value
func configure_auth(value):
	auth_config = value
func free_request(_weak, _object):
	pass
func check_scores_ready():
	return Scores != null
