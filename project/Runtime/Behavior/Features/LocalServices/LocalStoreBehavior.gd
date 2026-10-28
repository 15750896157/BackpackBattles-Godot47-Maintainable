extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalStore.gd")

static func set_profile_name(subject: Receiver, value: String) -> void:
	var trimmed = value.strip_edges()
	if not trimmed.is_empty() and trimmed != subject.profile.get("name", ""):
		subject.profile["name"] = trimmed
		subject.commit("profile")

static func create_workshop(subject: Receiver, metadata: String) -> int:
	var id = subject.next_id()
	subject.workshop[str(id)] = {"metadata": metadata, "owner": int(subject.profile.id), "title": "Local record", "tags": []}
	subject.commit("workshop")
	return id

static func set_workshop(subject: Receiver, id: int, key: String, value) -> bool:
	if not subject.workshop.has(str(id)):
		return false
	subject.workshop[str(id)][key] = value
	return subject.commit("workshop")

static func room_data(subject: Receiver, id: int, key: String, value) -> String:
	var current = subject.room(id)
	if current.is_empty():
		return ""
	if value != null:
		current.data[key] = str(value)
		subject.commit("rooms")
	return str(current.data.get(key, ""))

static func set_player_data(subject: Receiver, name: String, data: Dictionary, overwrite: bool) -> void:
	var existing: Dictionary = {} if overwrite else subject.players.get(name, {}).duplicate(true)
	existing.merge(data, true)
	subject.players[name] = existing
	subject.commit("players")
