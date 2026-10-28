extends Node
## Durable replacements for unavailable remote account, ranking and room services.
## Records generated here are local game data, never official server data.
signal changed(collection)
const ROOT = "user://local_services/"
const SCHEMA = 1
var profile: Dictionary = {}
var boards: Dictionary = {}
var workshop: Dictionary = {}
var rooms: Dictionary = {}
var players: Dictionary = {}
var accounts: Dictionary = {}
var _next_id: int = 3550001000

func _ready() -> void:
	load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd")._ready(self)

func reload() -> void:
	load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").reload(self)

func _read(collection: String, fallback: Dictionary) -> Dictionary:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd")._read(self, collection, fallback)

func commit(collection: String) -> bool:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").commit(self, collection)

func next_id() -> int:
	_next_id += 1
	commit("index")
	return _next_id

func set_profile_name(value: String) -> void:
	load("res://Runtime/Behavior/Features/LocalServices/LocalStoreBehavior.gd").set_profile_name(self, value)

func stat(name: String) -> int:
	return int(profile.get("stats", {}).get(name, 0))

func set_stat(name: String, value: int) -> void:
	profile.stats[name] = value
	commit("profile")

func achievement(name: String) -> bool:
	return bool(profile.get("achievements", {}).get(name, false))

func unlock(name: String) -> void:
	profile.achievements[name] = true
	commit("profile")

func scores(board: String, maximum: int = 2000) -> Array:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").scores(self, board, maximum)

func persist_score(board: String, player_name: String, score: float, metadata: Dictionary, source: String = "player_recorded") -> Dictionary:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").persist_score(self, board, player_name, score, metadata, source)

func delete_score(id: String) -> bool:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").delete_score(self, id)

func clear_board(board: String) -> void:
	boards[board] = []
	commit("boards")

func create_workshop(metadata: String = "") -> int:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalStoreBehavior.gd").create_workshop(self, metadata)

func set_workshop(id: int, key: String, value) -> bool:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalStoreBehavior.gd").set_workshop(self, id, key, value)

func create_room(owner: int, capacity: int) -> int:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").create_room(self, owner, capacity)

func room(id: int) -> Dictionary:
	return rooms.get(str(id), {})

func join_room(id: int, member: int) -> bool:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").join_room(self, id, member)

func room_data(id: int, key: String, value = null) -> String:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalStoreBehavior.gd").room_data(self, id, key, value)

func member_data(id: int, member: int, key: String, value = null) -> String:
	return load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").member_data(self, id, member, key, value)

func append_chat(id: int, member: int, message: String) -> void:
	load("res://Runtime/Behavior/LocalServices/LocalStoreBehavior.gd").append_chat(self, id, member, message)

func set_player_data(name: String, data: Dictionary, overwrite: bool = true) -> void:
	load("res://Runtime/Behavior/Features/LocalServices/LocalStoreBehavior.gd").set_player_data(self, name, data, overwrite)

