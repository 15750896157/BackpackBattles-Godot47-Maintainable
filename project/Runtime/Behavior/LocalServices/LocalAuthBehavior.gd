extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://LocalServices/LocalAuth.gd")

static func _register(subject: Receiver, player_name, email, password, confirmation, succeeded):
	if player_name.strip_edges().is_empty() or password != confirmation or subject._store().accounts.has(player_name):
		return subject._later("sw_registration_failed", ["Invalid local name/password or profile already exists"])
	subject._store().accounts[player_name] = {"email": email, "password_hash": password.sha256_text(), "local_only": true}
	subject._store().commit("accounts")
	subject.set_player_logged_in(player_name)
	return subject._later(succeeded)

static func login_player(subject: Receiver, username, password, _remember):
	var account = subject._store().accounts.get(str(username), {})
	if account.get("password_hash", "") == str(password).sha256_text():
		subject.set_player_logged_in(username)
		return subject._later("sw_login_succeeded")
	return subject._later("sw_login_failed", ["Local profile password does not match"])

static func reset_player_password(subject: Receiver, name, code, password, confirmation):
	if str(code) != "LOCAL" or password != confirmation or not subject._store().accounts.has(str(name)):
		return subject._later("sw_reset_password_failed", ["Local recovery code is LOCAL"])
	subject._store().accounts[str(name)]["password_hash"] = str(password).sha256_text()
	subject._store().commit("accounts")
	return subject._later("sw_reset_password_succeeded")
