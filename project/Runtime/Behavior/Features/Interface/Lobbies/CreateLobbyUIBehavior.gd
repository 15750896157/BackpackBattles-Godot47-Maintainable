extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/CreateLobbyUI.gd")

static func setConnected(subject: Receiver, connected: bool):
	Util.setConnected(connected, subject.LOBBIES, "lobby_created", subject, "onLobbyCreated")
	Util.setConnected(connected, subject.startTimer, "countdown_ended", subject, "onCountdownEnded")
	Util.setConnected(connected, subject.customRulesTimer, "timeout", subject, "applyCustomRules")

static func onLobbyCreated(subject: Receiver, lobbyId: String):
	subject.statusLabel.show()
	subject.setStatus("STATUS_LobbyCreated")
	subject.lobbyCodeNode.show()
	subject.lobbyCodeLabel.text = "[center]" + lobbyId.to_upper()
	subject.cancelButtonLabel.setTranslationKey("BUTTON_CloseLobby")

	subject.startGameButton.show()
	Sound.playSound(subject.successSound)

static func onCopyButtonPressed(subject: Receiver):
	DisplayServer.clipboard_set(subject.lobbyCodeLabel.text)
	var particles = ObjectPool.particleOneShot(subject.confirmationParticles, subject)
	particles.global_position = subject.copyButton.global_position + subject.copyButton.size * 0.5

static func onCountdownEnded(subject: Receiver):
	InputBlocker.restoreAllControls(InputBlocker.Source.Lobby)
	Game.startLobbyRun()
	Game.titleScreen.clearItems()

	subject.close()
	subject.emit_signal("close_requested", false)
