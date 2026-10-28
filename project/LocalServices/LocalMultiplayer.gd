extends Node
signal message_received(data)
signal session_started(name)
var mp_ws_ready = true
var mp_session_started = false
var mp_player_name = ""
func init_mp_session(name):
	mp_player_name = str(name)
	mp_session_started = true
	call_deferred("emit_signal", "session_started", name)
func _send_init_message():
	init_mp_session(mp_player_name)
func send(data: Dictionary):
	var store = get_node("/root/LocalServices")
	store.set_player_data(mp_player_name, {"local_multiplayer_state": data}, false)
	call_deferred("emit_signal", "message_received", data)
func send_to_server(_type, data):
	send(data)
