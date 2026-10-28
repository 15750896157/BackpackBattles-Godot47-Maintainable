extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalPlayers.gd")

static func get_player_data(subject: Receiver, name):
	subject.player_name = str(name)
	subject.player_data = subject._store().players.get(subject.player_name, {}).duplicate(true)
	return subject._later("sw_player_data_received", [name, subject.player_data])

static func delete_all_player_data(subject: Receiver, name):
	subject._store().players.erase(str(name))
	subject._store().commit("players")
	return subject._later("sw_player_data_removed", [name, {}])

static func delete_player_data(subject: Receiver, name, data):
	var existing = subject._store().players.get(str(name), {})
	for key in data: existing.erase(key)
	subject._store().players[str(name)] = existing
	subject._store().commit("players")
	return subject._later("sw_player_data_removed", [name, existing])
