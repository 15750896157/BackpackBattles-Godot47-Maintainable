extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalSteam.gd")

static func triggerItemDrop(subject: Receiver, _definition: int) -> int:
	var id = subject._store().next_id()
	subject._store().set_player_data(subject.getPersonaName(), {"last_local_drop": id}, false)
	return id

static func sendQueryUGCRequest(subject: Receiver, handle: int) -> void:
	var size = subject._queries.get(handle, []).size()
	subject._later("ugc_query_completed", [handle, 1, size, size, false])

static func createLobby(subject: Receiver, _type, maximum: int) -> int:
	var id = subject._store().create_room(subject.getSteamID(), maximum)
	subject._later("lobby_created", [1, id])
	subject._later("lobby_joined", [id, 0, false, 1])
	return id

static func joinLobby(subject: Receiver, id: int) -> bool:
	var accepted = subject._store().join_room(id, subject.getSteamID())
	subject._later("lobby_joined", [id, 0, false, 1 if accepted else 2])
	return accepted

static func leaveLobby(subject: Receiver, id: int) -> void:
	var room = subject._store().room(id)
	if not room.is_empty():
		room.members.erase(str(subject.getSteamID()))
		subject._store().commit("rooms")
	subject._later("lobby_chat_update", [id, subject.getSteamID(), subject.getSteamID(), 2])

static func setLobbyOwner(subject: Receiver, id: int, member: int) -> bool:
	var room = subject._store().room(id)
	if room.is_empty():
		return false
	room.owner = member
	return subject._store().commit("rooms")

static func setLobbyMemberData(subject: Receiver, id: int, key: String, value: String) -> void:
	subject._store().member_data(id, subject.getSteamID(), key, value)
	subject._later("lobby_data_update", [1, id, subject.getSteamID()])

static func sendLobbyChatMsg(subject: Receiver, id: int, message: String) -> bool:
	subject._store().append_chat(id, subject.getSteamID(), message)
	subject._later("lobby_message", [id, subject.getSteamID(), message, 1])
	return true
