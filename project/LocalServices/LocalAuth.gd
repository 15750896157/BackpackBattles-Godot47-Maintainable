extends Node
signal sw_login_succeeded
signal sw_login_failed(error)
signal sw_logout_succeeded
signal sw_registration_succeeded
signal sw_registration_user_pwd_succeeded
signal sw_registration_failed(error)
signal sw_email_verif_succeeded
signal sw_email_verif_failed(error)
signal sw_resend_conf_code_succeeded
signal sw_resend_conf_code_failed(error)
signal sw_session_check_complete(result)
signal sw_request_password_reset_succeeded
signal sw_request_password_reset_failed(error)
signal sw_reset_password_succeeded
signal sw_reset_password_failed(error)
signal sw_get_player_details_succeeded(details)
signal sw_get_player_details_failed
var logged_in_player = null
var logged_in_player_email = ""
var logged_in_anon = false
var token = "local"
var id_token = "local"
func _store():
	return get_node("/root/LocalServices")
func _later(signal_name, arguments = []):
	call_deferred("_deliver", signal_name, arguments)
	return self
func _deliver(signal_name, arguments):
	callv("emit_signal", [signal_name] + arguments)
func set_player_logged_in(player_name):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalAuthBehavior.gd").set_player_logged_in(self, player_name)

func get_anon_user_id() -> String:
	return str(_store().profile.id)
func register_player_anon(player_name = null):
	logged_in_anon = true
	set_player_logged_in(_store().profile.name if player_name == null else player_name)
	return _later("sw_registration_succeeded")
func register_player(player_name, email, password, confirmation):
	return _register(str(player_name), str(email), str(password), str(confirmation), "sw_registration_succeeded")
func register_player_user_password(player_name, password, confirmation):
	return _register(str(player_name), "", str(password), str(confirmation), "sw_registration_user_pwd_succeeded")
func _register(player_name, email, password, confirmation, succeeded):
	return load("res://Runtime/Behavior/LocalServices/LocalAuthBehavior.gd")._register(self, player_name, email, password, confirmation, succeeded)

func login_player(username, password, _remember = false):
	return load("res://Runtime/Behavior/LocalServices/LocalAuthBehavior.gd").login_player(self, username, password, _remember)

func logout_player():
	return load("res://Runtime/Behavior/Features/LocalServices/LocalAuthBehavior.gd").logout_player(self)

func verify_email(_name, _code):
	return _later("sw_email_verif_succeeded") # Local profiles do not send mail.
func resend_conf_code(_name):
	return _later("sw_resend_conf_code_succeeded")
func request_player_password_reset(name):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalAuthBehavior.gd").request_player_password_reset(self, name)

func reset_player_password(name, code, password, confirmation):
	return load("res://Runtime/Behavior/LocalServices/LocalAuthBehavior.gd").reset_player_password(self, name, code, password, confirmation)

func get_player_details(name):
	return load("res://Runtime/Behavior/Features/LocalServices/LocalAuthBehavior.gd").get_player_details(self, name)

func save_session(_lookup, _validator):
	_store().commit("profile")
func remove_stored_session():
	logout_player()
func load_session() -> Dictionary:
	return {"player_name": _store().profile.get("active_account", ""), "local_only": true}
func auto_login_player():
	return load("res://Runtime/Behavior/Features/LocalServices/LocalAuthBehavior.gd").auto_login_player(self)

func validate_player_session(_lookup, _validator, _scene = null):
	return auto_login_player()
func complete_session_check(result = null):
	return _later("sw_session_check_complete", [result])
