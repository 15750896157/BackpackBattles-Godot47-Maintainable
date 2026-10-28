extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/JoinLobbyUI.gd")

static func onJoinResult(subject: Receiver, res):
	print("res: ", Util.enumToString(subject.LOBBIES.JoinResult, res))

	if res == subject.LOBBIES.JoinResult.Unconfirmed:
		subject.statusLabel.setTranslationKey("STATUS_LobbyFound")

	elif res == subject.LOBBIES.JoinResult.Restricted_AlreadyStarted:
		subject.reset()

	else:

		subject.reset()

static func onConnected(subject: Receiver):
	subject.statusLabel.setTranslationKey("STATUS_LobbyJoined")
	subject.lobbyInfo.show()
	subject.onConfigChanged()
	if is_instance_valid(subject.startLocalGameButton):
		subject.startLocalGameButton.visible = subject.LOBBIES.isHost()
		subject.startLocalGameButton.disabled = false

static func reset(subject: Receiver):
	subject.lobbySearchbar.editable = true
	subject.lobbySearchbar.text = ""
	subject.joinButton.disabled = true
	subject.cancelButton.enable()
	subject.startTimer.hide()
	subject.lobbyInfo.hide()
	subject.statusLabel.setTranslationKey("STATUS_EnterCode")
	subject.customRulesIcon.onHoverEnd()
	if is_instance_valid(subject.startLocalGameButton): subject.startLocalGameButton.hide()

static func startCountdown(subject: Receiver):
	if is_instance_valid(subject.startLocalGameButton): subject.startLocalGameButton.hide()
	subject.startTimer.startCountdown(subject.LOBBIES.STARTGAME_COUNTDOWN)
	subject.cancelButton.disable()
	InputBlocker.disableAllControls(InputBlocker.Source.Lobby, Game.titleScreen)
	InputBlocker.enableControls(InputBlocker.Source.Lobby, Game.titleScreen.classAndLoadoutNode)

static func onCountdownEnded(subject: Receiver):
	InputBlocker.restoreAllControls(InputBlocker.Source.Lobby)
	Game.startLobbyRun()
	Game.titleScreen.clearItems()

	subject.close()
	subject.emit_signal("close_requested", false)
