extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/LobbyTimer.gd")

static func _ready(subject: Receiver):

	subject.LOBBIES.connect("update_ready_counter", Callable(subject, "updateReadyCounter"))
	subject.LOBBIES.connect("all_end_results_received", Callable(subject, "allEndResultsReceived"))
	subject.remove_child(subject.combatNode)
	Game.combatSceneNode.aboveUINode.add_child(subject.combatNode)

	Game.connect("shop_closed", Callable(subject, "showCombatTimer"))
	Game.connect("switch_to_shop", Callable(subject, "hideCombatTimer"))

static func updateTime(subject: Receiver):

	var limit_length = max(0, subject.remainingRoundTime)
	var clampedFloored = int(limit_length)

	if clampedFloored == subject.displayTime + 1:
		return
	subject.displayTime = clampedFloored

	var minutes = int(limit_length / 60)
	var seconds = int(fmod(limit_length, 60.0))

	subject.minutesLabel_shop.text = str(minutes)
	subject.secondsLabel_shop.text = "%02d" % seconds

	if limit_length <= 10:
		subject.setFont(subject.hurryFont, Game.SOFTWHITE)
	else:
		subject.setFont(subject.normalFont, Game.BROWN)

	if clampedFloored == 10:
		if not subject.shockwaveStarted:
			subject.shockwaveStarted = true
			Util.callDelayed(subject, "shockwave", 0.65)
	elif clampedFloored <= 9:
		if not subject.progressSprite.visible:
			subject.startProgressAni()
			subject.progressTween = subject.create_tween().set_parallel(true)
			subject.animateProgress(clampedFloored)

	var combatTimerReady = (subject.remainingRoundTime >= 0)
	subject.minutesLabel_combat.visible = combatTimerReady
	subject.secondsLabel_combat.visible = combatTimerReady
	subject.colonLabel_combat.visible = combatTimerReady
	subject.minutesLabel_combat.text = subject.minutesLabel_shop.text
	subject.secondsLabel_combat.text = subject.secondsLabel_shop.text

	var forceLoseTime = subject.FORCE_LOSE_TIME
	if Game.curRound == Game.MAX_ROUNDS_LOBBIES:
		forceLoseTime = 0

	if (subject.remainingRoundTime <= subject.FORCE_SPEED_TIME and
		not Game.fightEnded and
		not Game.combatTimer.isMaxSpeedForced()):
		print("force max speed")

		subject.forceSpeedAnimation()
		Game.combatTimer.forceMaxSpeed()

	if (subject.remainingRoundTime <= forceLoseTime and
		not Game.fightEnded):
		print("force lose combat")
		Game.forceLoseCombat()

	elif (subject.remainingRoundTime <= subject.FORCE_TRANSITION_TIME and
		Game.state == Game.State.Combat and
		Game.fightEnded and
		Game.curRound <= Game.MAX_ROUNDS_LOBBIES):

		print("force switch to shop")
		Game.combatSceneNode.forceSwitchToShop()

	elif (subject.remainingRoundTime <= 0 and
		Game.state == Game.State.Shop):

		subject.timerActive = false
		Game.forceSwitchToCombat()
		subject.showWaitLabel(true)

static func setFont(subject: Receiver, font, color):
	if font != subject.curFont:
		subject.curFont = font
		subject.minutesLabel_shop.set("theme_override_fonts/font", font)
		subject.minutesLabel_shop.set("theme_override_colors/font_color", color)
		subject.secondsLabel_shop.set("theme_override_fonts/font", font)
		subject.secondsLabel_shop.set("theme_override_colors/font_color", color)
		subject.colonLabel.set("theme_override_fonts/font", font)
		subject.colonLabel.set("theme_override_colors/font_color", color)
