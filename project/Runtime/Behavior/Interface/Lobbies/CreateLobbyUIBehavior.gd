extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/CreateLobbyUI.gd")

static func _ready(subject: Receiver):
	for button in subject.matchmakingModes.get_children():
		subject.matchmakingButtons.push_back(button)
		button.button_group = subject.buttonGroup
		Util.localizeFonts(button)
		var mode = subject.LOBBIES.MatchMaking[button.name]
		button.connect("pressed", Callable(subject, "onMatchmakingSelected").bind(mode))

	subject.speedSlider.connect("value_changed", Callable(subject, "onSpeedChanged"))

static func open(subject: Receiver):
	subject.show()
	subject.isOpen = true
	subject.lobbyCodeNode.hide()
	subject.startGameButton.hide()

	subject.cancelButton.enable()
	subject.cancelButtonLabel.setTranslationKey("BUTTON_Cancel")
	subject.createLobbyButton.disabled = false
	subject.createLobbyButton.show()
	subject.statusLabel.hide()
	subject.speedSlider.editable = true
	subject.speedSlider.max_value = subject.LOBBIES.SpeedLevel.size()
	subject.speedSlider.tick_count = subject.LOBBIES.SpeedLevel.size()
	subject.speedSlider.set_value_no_signal(subject.LOBBIES.getSpeed())

	subject.memberLimitSpinbox.editable = true
	subject.memberLimitSpinbox.max_value = subject.LOBBIES.MAX_MEMBERS
	subject.memberLimitSpinbox.min_value = subject.LOBBIES.MIN_MEMBERS
	subject.memberLimitSpinbox.set_value_no_signal(subject.LOBBIES.getLobbySize())
	subject.memberLimitSpinbox.apply()

	subject.customRulesIcon.texture = CustomRules.defaultIcon
	subject.customRulesTooltip.hide()

	for button in subject.matchmakingButtons:
		button.set_pressed_no_signal(false)
	subject.matchmakingButtons[subject.LOBBIES.matchMaking].set_pressed_no_signal(true)
	subject.matchmakingTooltip.hide()

	subject.prioritizeHostButton.set_pressed_no_signal(subject.LOBBIES.prioritizeHost)

	subject.startTimer.hide()
	subject.setConnected(true)
	Game.suspendRunState()

static func onStartGamePressed(subject: Receiver):
	Game.onClickButton()

	subject.startGameButton.hide()
	subject.cancelButton.disable()
	subject.speedSlider.editable = false
	subject.memberLimitSpinbox.editable = false
	subject.LOBBIES.startCountdown()
	subject.startTimer.startCountdown(subject.LOBBIES.STARTGAME_COUNTDOWN)

	Util.finishTimer(subject.customRulesTimer)

	InputBlocker.disableAllControls(InputBlocker.Source.Lobby, subject)
	InputBlocker.disableAllControls(InputBlocker.Source.Lobby, Game.titleScreen)
	InputBlocker.enableControls(InputBlocker.Source.Lobby, Game.titleScreen.classAndLoadoutNode)
