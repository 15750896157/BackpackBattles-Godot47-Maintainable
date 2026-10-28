extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/JoinLobbyUI.gd")

static func _ready(subject: Receiver):
	subject.add_to_group("Localized")
	Util.localizeFonts(subject.lobbySearchbar)
	subject.speedSlider.editable = false
	if ProjectSettings.get_setting("application/config/local_services", false):
		# A saved local room has no remote host to start its countdown.
		subject.startLocalGameButton = subject.joinButton.duplicate(Node.DUPLICATE_SCRIPTS)
		subject.startLocalGameButton.name = "StartLocalGameButton"
		subject.startLocalGameButton.position = Vector2(1016, 636)
		subject.startLocalGameButton.size = Vector2(226, 44)
		subject.startLocalGameButton.text = Util.tra("BUTTON_StartGame")
		subject.startLocalGameButton.set("translationKey", "BUTTON_StartGame")
		subject.startLocalGameButton.set("maxSize", 226.0)
		subject.startLocalGameButton.flat = true
		subject.startLocalGameButton.hide()
		subject.add_child(subject.startLocalGameButton)
		subject.startLocalGameButton.pressed.connect(subject.onStartLocalGamePressed)
		Util.localizeFonts(subject.startLocalGameButton)

static func setConnected(subject: Receiver, connected: bool):
	Util.setConnected(connected, subject.LOBBIES, "join_result", subject, "onJoinResult")
	Util.setConnected(connected, subject.LOBBIES, "lobby_join_confirmed", subject, "onConnected")
	Util.setConnected(connected, subject.LOBBIES, "config_changed", subject, "onConfigChanged")
	Util.setConnected(connected, subject.LOBBIES, "kicked", subject, "onKickedFromLobby")
	Util.setConnected(connected, subject.LOBBIES, "lobby_closed", subject, "onLobbyClosed")
	Util.setConnected(connected, subject.LOBBIES, "start_countdown", subject, "startCountdown")
	Util.setConnected(connected, subject.startTimer, "countdown_ended", subject, "onCountdownEnded")

static func onSearchbarTextChanged(subject: Receiver, newText):
	var caretPosition = subject.lobbySearchbar.caret_column
	var cleanedCode = ""
	newText = newText.to_lower()
	for i in newText.length():
		var character = newText[i]
		if character in subject.LOBBIES.symbolDict:
			cleanedCode += character
		else:
			if i < caretPosition:
				caretPosition -= 1

	subject.curLobbyCode = cleanedCode
	subject.lobbySearchbar.text = cleanedCode.to_upper()
	subject.lobbySearchbar.caret_column = caretPosition

	subject.joinButton.disabled = not subject.isLobbyCodeWellFormated(cleanedCode)

static func onConfigChanged(subject: Receiver):

	subject.speedSlider.editable = true
	subject.speedSlider.set_value_no_signal(subject.LOBBIES.getSpeed())
	subject.speedSlider.editable = false

	if subject.LOBBIES.customRules != "":
		subject.customRulesIcon.onCustomRulesChanged()
		subject.customRulesIcon.show()
	else:
		subject.customRulesIcon.hide()
		subject.customRulesIcon.onHoverEnd()

	var matchmakingName = subject.LOBBIES.MatchMaking.keys()[subject.LOBBIES.getMatchmaking()]
	subject.matchmakingLabel.setTranslationKey("MATCHING_" + matchmakingName + "_NAME")
	subject.matchmakingTooltipArea.keyword = "MATCHING_" + matchmakingName
	subject.prioritizeHostNode.visible = subject.LOBBIES.getPrioritizeHost()
