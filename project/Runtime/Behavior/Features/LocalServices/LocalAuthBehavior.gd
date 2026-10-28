extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalAuth.gd")

static func set_player_logged_in(subject: Receiver, player_name):
	subject.logged_in_player = player_name
	subject._store().set_profile_name(str(player_name))
	subject._store().profile["active_account"] = str(player_name)
	subject._store().commit("profile")

static func logout_player(subject: Receiver):
	subject.logged_in_player = null
	subject._store().profile.erase("active_account")
	subject._store().commit("profile")
	return subject._later("sw_logout_succeeded")

static func request_player_password_reset(subject: Receiver, name):
	if subject._store().accounts.has(str(name)):
		return subject._later("sw_request_password_reset_succeeded")
	return subject._later("sw_request_password_reset_failed", ["Local profile was not found"])

static func get_player_details(subject: Receiver, name):
	var details = subject._store().accounts.get(str(name), {}).duplicate(true)
	details.erase("password_hash")
	return subject._later("sw_get_player_details_succeeded", [details])

static func auto_login_player(subject: Receiver):
	var name = subject._store().profile.get("active_account", "")
	if name != "": subject.set_player_logged_in(name)
	return subject._later("sw_session_check_complete", [name != ""])
