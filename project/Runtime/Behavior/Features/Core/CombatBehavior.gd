extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Combat.gd")

static func pve_reset_lifecycle(subject: Receiver):
	subject.pve_lifecycle_epoch += 1
	subject.hideTimer.stop()
	subject.animationTimer.stop()
	if is_instance_valid(subject.backgroundAnimation):
		subject.backgroundAnimation.stop()
		subject.backgroundAnimation.speed_scale = 1.0
	subject.stopTimeTween()
	subject.clearParticles()
	subject.stopClipping()
	subject.combatLogButton.disabled = true
	subject.combatLogButton.hide()
	subject.set_process_unhandled_input(false)
	subject.reset()

static func popInTrophy(subject: Receiver):
	if (Game.isArenaMode() and
		Game.curRound == Game.SUBCLASS_ROUND and
		Game.getTries() > 0 and
		Game.getTries() < Game.MAX_TRIES):

		subject.subclassRoundHealAnimation.play("Appear")
		subject.refillHeart()
		Game.giveTry()

	subject.trophies[Game.wins - 1].popIn()

static func loseHeart(subject: Receiver):
	if (Game.isArenaMode() and
		Game.curRound == Game.SUBCLASS_ROUND and
		Game.getTries() > 0):

		subject.subclassRoundHealAnimation.play("Appear")
		subject.loseAndRefillHeart()
		Game.giveTry()
	else:
		subject.hearts[Game.tries].loseHeart()

static func _unhandled_input(subject: Receiver, event: InputEvent) -> void :
	if InputBlocker.isActive(): return

	if ((event.is_action_pressed("ui_accept") or
		event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_LEFT) and
		event.is_pressed()):

		subject.skipIfPossible()

static func hideRoundResult(subject: Receiver):
	if subject.result == Game.RoundResult.Loss:
		subject.roundAnimation.play("LoseHide")
	else:
		subject.roundAnimation.play("WinHide")

	if subject.surviveRoundsCounter.visible:
		subject.surviveRoundsCounterAnimation.advance(2)
		subject.surviveRoundsCounterAnimation.play("Hide")

	if subject.subclassRoundHealLabel.visible:
		subject.subclassRoundHealAnimation.play("Disappear")

static func switchAway(subject: Receiver):
	Game.combatLog.close()
	subject.combatLogButton.disabled = true
	subject.combatLogButton.hide()
	InputBlocker.restoreAllControls(InputBlocker.Source.CombatUI)
	Game.PLAYER.INVENTORY.enableItemTooltips()
	subject.hideTimer.start(5)

	subject.startClipping()

static func cancelSurvivalMode(subject: Receiver):
	if not subject.survivalPromptActive: return

	subject.survivalPromptActive = false
	Game.cancelSurviveMode()
	subject.survivalPromptAnimation.play("Cancel")
	subject.survivalPromptAnimation.advance(0.01)
	Util.callDelayed(subject, "cancelSurvivalMode_continue", 1.0)

static func startSurvivalMode(subject: Receiver):
	if not subject.survivalPromptActive: return

	subject.survivalPromptActive = false
	subject.refillHeart()
	Game.startSurvivalMode()

	subject.survivalPromptAnimation.play("Confirm")
	subject.survivalPromptAnimation.advance(0.01)
	Util.callDelayed(subject, "startSurvivalMode_continue", 1.0)
	InputBlocker.activate(InputBlocker.Source.SceneSwitch)
	Sound.playSound(subject.survivalSound)

static func updateSurvivalCounter(subject: Receiver):

	var roundsToSurvive = Game.getRoundsToSurvive()
	if roundsToSurvive == 1:
		subject.surviveRoundsCounterLabel.text = Util.tra("UI_SurviveCounter_OneRound")
	else:
		subject.surviveRoundsCounterLabel.text = Util.tra("UI_SurviveCounter").format({"rounds": roundsToSurvive})

static func _process(subject: Receiver, delta):
	var xPos = subject.backgroundNode.position.x
	xPos /= 1920
	xPos = - (1.0 + xPos)
	xPos += 0.02
	subject.clipMaterial.set_shader_parameter("xPosition", xPos)

static func instanceLobbyTrophies(subject: Receiver):
	for i in Game.wins:
		var trophy = subject.trophyScene.instantiate()
		subject.lobbyTrophies.push_back(trophy)
		subject.lobbyTrophyPosition.add_child(trophy)
		trophy.setFull()
		trophy.self_modulate = Color.TRANSPARENT

static func trophiesFinished(subject: Receiver):
	subject.chestnutAnimation.play("Close")

	if Game.curMode == Game.Mode.Lobbies:
		for trophy in subject.lobbyTrophies:
			trophy.queue_free()
		subject.lobbyTrophies.clear()

static func setLeagueProgress(subject: Receiver, progress: float):
	subject.leagueProgressBarMaterial.set_shader_parameter("progress", progress)

	var barSize = subject.leagueProgressBar.region_rect.size.x * subject.leagueProgressBar.global_scale.x
	var barStart = subject.leagueProgressBar.global_position.x - barSize * 0.5

	subject.barBorderParticles.global_position.x = barStart + progress * barSize

static func setLeague(subject: Receiver, league):
	subject.leagueLabel.text = Game.getLeagueName(league)
	subject.leagueLabel.set("theme_override_colors/font_color", Game.leagueColors[league])
	subject.leagueEmblem.setLeague(league)
	subject.barBorderParticles.modulate = Game.leagueColors[league].lightened(0.2)
	subject.leagueProgressBar.modulate = Game.leagueColors[league]

static func advanceTime(subject: Receiver, time):
	Game.combatTimer.advanceTime(time)
	if is_instance_valid(subject.backgroundAnimation): subject.backgroundAnimation.speed_scale = subject.ADVANCE_SPEED
	var dur = time / (subject.ADVANCE_SPEED - 1.0)
	Util.changeTimer(subject.animationTimer, dur)

static func interpolateTime(subject: Receiver, time):
	subject.stopTimeTween()
	var dur = 0.1 + abs(time - subject.animatedTime) * 0.05
	subject.animationTween.interpolate_method(subject, "setTime", subject.animatedTime, time, dur, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	subject.animationTween.start()

static func showLobbyResults(subject: Receiver):
	subject.lobbyResultAni.play("Appear")
	subject.lobbyResultRankLabel.formatParams = {"rank": RunDatabase.lobbies.getResultRank()}
	subject.lobbyResultRankLabel.updateText()

	subject.lobbyResultScoreLabel.formatParams = {"score": RunDatabase.lobbies.getResultScore()}
	subject.lobbyResultScoreLabel.updateText()

static func onLobbyFinishButtonPressed(subject: Receiver):

	subject.skipRunResult()

	subject.lobbyResultAni.play("Disappear")
	subject.lobbyResultsReceived = false
	subject.buildViewer.close()
	subject.buildViewer = null

	RunDatabase.lobbies.leaveLobby()

	if Game.hasArenaRunState():
		Game.initPlayerFromRunstate(Game.Mode.Unranked)
		Game.readRoundResultsFromRunState(Game.Mode.Unranked)
