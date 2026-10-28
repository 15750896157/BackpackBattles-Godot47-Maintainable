extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/CombatLog/CombatLogFilterPanel.gd")

static func open(subject: Receiver):
	subject.isOpen = true
	for button in subject.filterButtons:
		button.show()

	subject.offset_top = subject.MARGIN_TOP_OPEN
	subject.offset_right = subject.MARGIN_RIGHT_OPEN
	subject.openButton.flip_h = false

	if not Game.isTutorialDone(Game.TutorialSteps.CombatLogButtons):
		Game.setTutorialDone(Game.TutorialSteps.CombatLogButtons)
		Game.combatLog.buttonTutorialAni.play("RESET")

static func close(subject: Receiver):
	subject.isOpen = false
	for button in subject.filterButtons:
		button.hide()
	for button in subject.replayButtons:
		button.button_pressed = false

	subject.offset_top = - 52
	subject.offset_right = 83
	subject.openButton.flip_h = true

static func onPlayBackwardsButtonToggled(subject: Receiver, pressed):
	if not subject.buttonsReset:
		subject.resetReplayButtons(subject.playBackwardsButton)
		if pressed:
			Game.combatLog.replayCombat(false, - 1.0)
		else:
			Game.combatLog.stopReplay()

static func onPlayFromEndButtonToggled(subject: Receiver, pressed):
	if not subject.buttonsReset:
		subject.resetReplayButtons(subject.playFromEndButton)
		if pressed:
			Game.combatLog.replayCombat(true, - 1.0)
		else:
			Game.combatLog.stopReplay()
