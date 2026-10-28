extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalStore.gd")

static func _ready(subject: Receiver) -> void:
	subject.process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(subject.ROOT)
	subject.reload()
	if subject.profile.is_empty():
		subject.profile = {"id": 3550000001, "name": "Local Player", "language": "english", "stats": {}, "achievements": {}, "presence": {}}
		subject.commit("profile")

static func reload(subject: Receiver) -> void:
	subject.profile = subject._read("profile", {})
	subject.boards = subject._read("boards", {})
	subject.workshop = subject._read("workshop", {})
	subject.rooms = subject._read("rooms", {})
	subject.players = subject._read("players", {})
	subject.accounts = subject._read("accounts", {})
	var index = subject._read("index", {"next_id": 3550001000})
	subject._next_id = int(index.get("next_id", 3550001000))

static func _read(subject: Receiver, collection: String, fallback: Dictionary) -> Dictionary:
	for suffix in [".json", ".json.bak"]:
		var path = subject.ROOT + collection + suffix
		if FileAccess.file_exists(path):
			var decoded = JSON.parse_string(FileAccess.get_file_as_string(path))
			if decoded is Dictionary and decoded.get("schema", 0) == subject.SCHEMA and decoded.get("data") is Dictionary:
				return decoded.data
	return fallback.duplicate(true)

static func commit(subject: Receiver, collection: String) -> bool:
	var data = subject.get(collection) if collection != "index" else {"next_id": subject._next_id}
	var path = subject.ROOT + collection + ".json"
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Local service cannot save " + collection + ": " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({"schema": subject.SCHEMA, "data": data}, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		var backup_error = DirAccess.rename_absolute(path, path + ".bak")
		if backup_error != OK:
			push_error("Local service backup failed: " + collection)
			return false
	var save_error = DirAccess.rename_absolute(temporary, path)
	if save_error != OK:
		push_error("Local service commit failed: " + collection)
		return false
	subject.changed.emit(collection)
	return true

static func scores(subject: Receiver, board: String, maximum: int) -> Array:
	var rows: Array = subject.boards.get(board, []).duplicate(true)
	rows.sort_custom(func(a, b): return float(a.get("score", 0)) > float(b.get("score", 0)))
	return rows.slice(0, maxi(0, maximum))

static func persist_score(subject: Receiver, board: String, player_name: String, score: float, metadata: Dictionary, source: String) -> Dictionary:
	var id = str(subject.next_id())
	var row = {"score_id": id, "player_name": player_name, "score": score, "metadata": metadata.duplicate(true), "source": source, "recorded_at": Time.get_unix_time_from_system()}
	var rows: Array = subject.boards.get(board, [])
	rows.append(row)
	if rows.size() > 2000:
		rows = rows.slice(rows.size() - 2000)
	subject.boards[board] = rows
	subject.commit("boards")
	return row

static func delete_score(subject: Receiver, id: String) -> bool:
	for board in subject.boards.keys():
		var rows: Array = subject.boards[board]
		for index in range(rows.size() - 1, -1, -1):
			if str(rows[index].get("score_id", "")) == id:
				rows.remove_at(index)
				subject.boards[board] = rows
				subject.commit("boards")
				return true
	return false

static func create_room(subject: Receiver, owner: int, capacity: int) -> int:
	var id = subject.next_id()
	subject.rooms[str(id)] = {"owner": owner, "capacity": capacity, "data": {}, "members": {str(owner): {}}, "chat": [], "closed": false, "local": true}
	subject.commit("rooms")
	return id

static func join_room(subject: Receiver, id: int, member: int) -> bool:
	var value = subject.room(id)
	if value.is_empty() or value.get("closed", false):
		return false
	if not value.members.has(str(member)) and value.members.size() >= int(value.capacity):
		return false
	if not value.members.has(str(member)):
		value.members[str(member)] = {}
	subject.commit("rooms")
	return true

static func member_data(subject: Receiver, id: int, member: int, key: String, value) -> String:
	var current = subject.room(id)
	if current.is_empty():
		return ""
	if not current.members.has(str(member)):
		current.members[str(member)] = {}
	if value != null:
		current.members[str(member)][key] = str(value)
		subject.commit("rooms")
	return str(current.members[str(member)].get(key, ""))

static func append_chat(subject: Receiver, id: int, member: int, message: String) -> void:
	var current = subject.room(id)
	if not current.is_empty():
		current.chat.append({"member": member, "message": message, "at": Time.get_unix_time_from_system()})
		if current.chat.size() > 500:
			current.chat.pop_front()
		subject.commit("rooms")
