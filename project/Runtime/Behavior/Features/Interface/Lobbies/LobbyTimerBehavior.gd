extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/LobbyTimer.gd")

static func forwardTo(subject: Receiver, _remainingRoundTime: float):
	subject.particles.activate()
	subject.progressTween = Util.refreshTween(subject.progressTween).set_parallel(true)
	if not subject.progressSprite.visible:
		subject.startProgressAni()
	subject.animateProgress(_remainingRoundTime)

	if _remainingRoundTime < subject.remainingRoundTime:
		subject.nextFightTime = Steam.getServerRealTime() + _remainingRoundTime
		subject.setTimer(_remainingRoundTime)

static func startProgressAni(subject: Receiver):
	subject.progressSprite.show()
	subject.progressSprite.modulate = Color(1, 0.890196, 0.215686, 1.0)
	subject.progressSprite.material.set_shader_parameter("revealState", 0.0)

static func animateProgress(subject: Receiver, duration: float):
	subject.progressTween.tween_property(subject.progressSprite.material,
		"shader_parameter/revealState", 1.0, duration)
	subject.progressTween.tween_property(subject.progressSprite,
		"modulate", subject.PROGRESS_MODULATE_END, duration)
	subject.progressTween.tween_property(subject.progressSprite,
		"modulate", Color.TRANSPARENT, 3).from(subject.PROGRESS_MODULATE_END).set_delay(duration)

static func showWaitLabel(subject: Receiver, showWait: bool):
	subject.waitingLabel.visible = showWait
	subject.minutesLabel_shop.visible = not showWait
	subject.secondsLabel_shop.visible = not showWait
	subject.colonLabel.visible = not showWait

	if showWait:
		subject.checkMark.hide()
		subject.readyButton.disable()
		subject.readyCounter.hide()
	else:
		subject.readyButton.enable()
		subject.progressSprite.hide()
		subject.shockwaveStarted = false

static func _physics_process(subject: Receiver, delta):
	var previous = subject.serverTime
	subject.serverTime = Steam.getServerRealTime()
	if previous != subject.serverTime:

		subject.preciseTime = subject.serverTime
	else:
		subject.preciseTime += subject.FRAMETIME

	if subject.timerActive:
		var before = int(subject.remainingRoundTime)
		subject.remainingRoundTime = subject.nextFightTime - subject.preciseTime
		if before != int(subject.remainingRoundTime):
			subject.updateTime()

static func onReadyPressed(subject: Receiver):
	if (Game.state == Game.State.Shop and
		Game.canSwitchToCombat and
		Game.draggedItem == null):

		subject.checkMark.show()
		subject.LOBBIES.setReady()
		subject.readyButton.disable()

static func updateReadyCounter(subject: Receiver):
	var numReady = subject.LOBBIES.countReadyMembers()
	if numReady > 0:
		subject.readyCounter.show()
		subject.readyCounter.text = str(numReady) + "/" + str(subject.LOBBIES.getNumMembers())
