extends Node
## Local compatibility API. Every method below operates on files on this machine.
signal current_stats_received(game, result, user)
signal leaderboard_find_result(handle, found)
signal leaderboard_scores_downloaded(message, handle, entries)
signal leaderboard_score_uploaded(result, handle, score)
signal leaderboard_ugc_set(handle, result)
signal ugc_query_completed(handle, result, returned, total, cached)
signal item_created(result, id, accept_tos)
signal item_updated(result, accept_tos)
signal lobby_created(result, id)
signal lobby_joined(id, permissions, locked, response)
signal lobby_chat_update(id, changed, making_change, state)
signal lobby_message(id, member, buffer, type)
signal lobby_data_update(success, id, member)
signal floating_gamepad_text_input_dismissed
var _handles: Dictionary = {}
var _queries: Dictionary = {}
var _updates: Dictionary = {}
var _handle_id = 1

func _store():
	return get_node("/root/LocalServices")

func _later(signal_name: String, arguments: Array = []) -> void:
	call_deferred("_deliver", signal_name, arguments)

func _deliver(signal_name: String, arguments: Array) -> void:
	callv("emit_signal", [signal_name] + arguments)

func steamInit(_retrieve_stats = false) -> Dictionary:
	return {"status": 1, "verbal": "Local file services ready", "local": true}
func run_callbacks() -> void:
	pass
func loggedOn() -> bool:
	return true
func isSubscribed() -> bool:
	return true
func isSubscribedFromFamilySharing() -> bool:
	return false
func getSteamID() -> int:
	return int(_store().profile.id)
func getAppID() -> int:
	return 2427700
func getPersonaName() -> String:
	return str(_store().profile.name)
func setPersonaName(value: String) -> void:
	_store().set_profile_name(value)
func getCurrentGameLanguage() -> String:
	return str(_store().profile.get("language", "english"))
func isSteamRunningOnSteamDeck() -> bool:
	return false
func getServerRealTime() -> int:
	return int(Time.get_unix_time_from_system())
func requestCurrentStats() -> bool:
	_later("current_stats_received", [getAppID(), 1, getSteamID()])
	return true
func getStatInt(key: String) -> int:
	return _store().stat(key)
func setStatInt(key: String, value: int) -> bool:
	_store().set_stat(key, value)
	return true
func storeStats() -> bool:
	return _store().commit("profile")
func getAchievement(name: String) -> Dictionary:
	return {"ret": true, "achieved": _store().achievement(name)}
func setAchievement(name: String) -> bool:
	_store().unlock(name)
	return true
func setRichPresence(key: String, value) -> bool:
	_store().profile.presence[key] = str(value)
	_store().commit("profile")
	return true
func triggerItemDrop(_definition: int) -> int:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").triggerItemDrop(self, _definition)

func destroyResult(_handle: int) -> void:
	pass
func showFloatingGamepadTextInput(_mode, _x, _y, _width, _height) -> bool:
	_later("floating_gamepad_text_input_dismissed")
	return false

func findLeaderboard(board: String) -> int:
	var handle = _handle_id
	_handle_id += 1
	_handles[handle] = board
	_later("leaderboard_find_result", [handle, 1])
	return handle
func downloadLeaderboardEntries(_start, maximum, _type, handle: int) -> void:
	load("res://Runtime/Behavior/LocalServices/LocalSteamBehavior.gd").downloadLeaderboardEntries(self, _start, maximum, _type, handle)

func uploadLeaderboardScore(score, _keep_best, details, handle: int) -> bool:
	return load("res://Runtime/Behavior/LocalServices/LocalSteamBehavior.gd").uploadLeaderboardScore(self, score, _keep_best, details, handle)

func createQueryUGCDetailsRequest(ids) -> int:
	var handle = _handle_id
	_handle_id += 1
	_queries[handle] = Array(ids)
	return handle
func setReturnMetadata(_handle, _enabled) -> bool:
	return true
func sendQueryUGCRequest(handle: int) -> void:
	load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").sendQueryUGCRequest(self, handle)

func getQueryUGCMetadata(handle: int, index: int) -> String:
	return load("res://Runtime/Behavior/LocalServices/LocalSteamBehavior.gd").getQueryUGCMetadata(self, handle, index)

func releaseQueryUGCRequest(handle: int) -> void:
	_queries.erase(handle)
func createItem(_app, _type) -> int:
	var id = _store().create_workshop()
	_later("item_created", [1, id, false])
	return id
func startItemUpdate(_app, id: int) -> int:
	var handle = _handle_id
	_handle_id += 1
	_updates[handle] = id
	return handle
func _set_item(handle: int, key: String, value) -> bool:
	return _store().set_workshop(int(_updates.get(handle, 0)), key, value)
func setItemTitle(handle, value) -> bool:
	return _set_item(handle, "title", value)
func setItemDescription(handle, value) -> bool:
	return _set_item(handle, "description", value)
func setItemUpdateLanguage(handle, value) -> bool:
	return _set_item(handle, "language", value)
func setItemVisibility(handle, value) -> bool:
	return _set_item(handle, "visibility", value)
func setItemTags(handle, value) -> bool:
	return _set_item(handle, "tags", value)
func setItemContent(handle, value) -> bool:
	return _set_item(handle, "content_path", value)
func setItemPreview(handle, value) -> bool:
	return _set_item(handle, "preview_path", value)
func setItemMetadata(handle, value) -> bool:
	return _set_item(handle, "metadata", value)
func submitItemUpdate(_handle, _description = "") -> bool:
	_later("item_updated", [1, false])
	return true

func createLobby(_type, maximum: int) -> int:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").createLobby(self, _type, maximum)

func joinLobby(id: int) -> bool:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").joinLobby(self, id)

func leaveLobby(id: int) -> void:
	load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").leaveLobby(self, id)

func getLobbyOwner(id: int) -> int:
	return int(_store().room(id).get("owner", 0))
func setLobbyOwner(id: int, member: int) -> bool:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").setLobbyOwner(self, id, member)

func setLobbyData(id: int, key: String, value: String) -> bool:
	_store().room_data(id, key, value)
	_later("lobby_data_update", [1, id, id])
	return true
func getLobbyData(id: int, key: String) -> String:
	return _store().room_data(id, key)
func setLobbyMemberData(id: int, key: String, value: String) -> void:
	load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").setLobbyMemberData(self, id, key, value)

func getLobbyMemberData(id: int, member: int, key: String) -> String:
	return _store().member_data(id, member, key)
func sendLobbyChatMsg(id: int, message: String) -> bool:
	return load("res://Runtime/Behavior/Features/LocalServices/LocalSteamBehavior.gd").sendLobbyChatMsg(self, id, message)

