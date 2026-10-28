extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Combat.gd")

static func _ready(subject: Receiver) -> void :
	subject.set_process_unhandled_input(false)

	Game.connect("shop_closed", Callable(subject, "onSwitchingToCombat"))
	Game.connect("combat_scene_entered", Callable(subject, "onSwitchedToCombat"))
	Game.connect("combat_start", Callable(subject, "onCombatStart"))
	Game.connect("combat_end", Callable(subject, "onCombatEnd"))
	Game.connect("shop_opened", Callable(subject, "reset"))
	Game.connect("returned_to_title", Callable(subject, "reset"))
	Game.connect("warp_cursor_combat", Callable(subject, "onCursorWarp"))

	subject.barBorderParticles.emitting = false
	subject.currentStats.hide()

	for child in subject.get_node("UI/Trophies").get_children():
		if child.name.begins_with("Trophy"):
			subject.trophies.push_back(child)

	for child in subject.survivalTrophies.get_children():
		subject.trophies.push_back(child)

	for child in subject.get_node("UI/Hearts").get_children():
		if child.name.begins_with("Heart"):
			subject.hearts.push_back(child)

	for child in subject.backgroundNode.get_children():
		if child.is_in_group("Clipped"):
			subject.clippedNodes.push_back(child)

	subject.combatLogButton.disabled = true
	subject.combatLogButton.hide()

	subject.hide()
	subject.set_process(false)

	subject.chestnutPupil.deactivate()

	subject.call_deferred("ready_deferred")

static func onSwitchingToCombat(subject: Receiver):
	subject.show()
	subject.hideTimer.stop()
	subject.animationTween.stop_all()
	subject.animationTween.remove_all()

	subject.backgroundAnimation.play("Round")
	subject.backgroundAnimation.seek(0, true)
	subject.pve_lifecycle_epoch += 1
	if is_instance_valid(Game.OPPONENT):
		Util.callDelayed(subject, "pve_clash_swords", 1.0, [subject.pve_lifecycle_epoch, Game.OPPONENT.get_instance_id()])
	return

static func clashSwords(subject: Receiver):
	if Expedition.enabled and (Game.state != Game.State.Combat or not is_instance_valid(Game.OPPONENT)):
		return
	Game.PLAYER.animation.play("CombatStart")
	Game.OPPONENT.animation.play("OpponentCombatStart")
	Util.callDelayed(Sound, "playSound", 1, [subject.swordClashSound, - 5, Util.rng.randf_range(0.9, 1.0)])

static func pve_clash_swords(subject: Receiver, epoch: int, opponent_id: int):
	if epoch != subject.pve_lifecycle_epoch or Game.state != Game.State.Combat: return
	if not is_instance_valid(Game.OPPONENT) or Game.OPPONENT.get_instance_id() != opponent_id: return
	if Expedition.flow.screen_state != "COMBAT_RUNNING": return
	Game.PLAYER.animation.play("CombatStart")
	Game.OPPONENT.animation.play("OpponentCombatStart")
	Sound.playSound(subject.swordClashSound, -5)

static func showSurvivalPrompt(subject: Receiver):
	subject.survivalPromptActive = true

	var cancelLabel = subject.survivalPrompt.get_node("TakeWin/RichTextLabel")
	var survivalLabel = subject.survivalPrompt.get_node("StartSurvival/RichTextLabel")

	cancelLabel.text = "[center]" + Util.tra("UI_CancelSurvival")

	survivalLabel.text = "[center]" + Util.tra("UI_StartSurvival").format({
		"rounds": Util.wrapInColor(str(Game.MAX_ROUNDS), Util.paramColor),
		"roundsLeft": Util.wrapInColor(str(Game.getRoundsToSurvive()), Util.paramColor)
	})

	if Game.curMode == Game.Mode.Ranked or Game.isRankedSwitchMode():
		var rankLow = Util.addPlus(Game.getRankingDif_survival_worst())
		var rankHigh = Util.addPlus(Game.getRankingDif_survival_best())
		var rank_noSurvival = Util.addPlus(Game.getRankingDif_noSurvival())

		survivalLabel.text += "\n" + Util.tra("UI_StartSurvival_Ranked").format(
			{"rankLow": Util.wrapInColor(rankLow, Util.paramColor),
			"rankHigh": Util.wrapInColor(rankHigh, Util.paramColor)})

		cancelLabel.text += "\n" + Util.tra("UI_CancelSurvival_Ranked").format(
			{"rank": Util.wrapInColor(rank_noSurvival, Util.paramColor)})

	subject.survivalPromptAnimation.play("Show")

	subject.survivalHealHint.visible = Game.tries < Game.MAX_TRIES

	subject.updateSurvivalCounter()

static func givePerfectRunBonus(subject: Receiver):
	var perfectRunLabel = subject.get_node("UI/PerfectRun/Label")
	if Game.isSurvivalMode():
		perfectRunLabel.translationKey = "BANNER_PerfectSurvival"
	else:
		perfectRunLabel.translationKey = "BANNER_PerfectWin"

	perfectRunLabel.updateText()

	var label = subject.get_node("UI/10Wins/Label")

	if Game.isSurvivalMode():
		label.translationKey = "BANNER_Survival"
	else:
		label.translationKey = "BANNER_10Wins"

	label.updateLocale()

	var delay = 0.8
	Util.callDelayed(subject.bonusAnimation, "play", delay, ["PerfectRun"])
	subject.bonusTrophyParticles.amount = Game.getBonusTrophies()

static func giveMaxWinsBonus(subject: Receiver):
	var label = subject.get_node("UI/10Wins/Label")

	if Game.isSurvivalMode():
		label.translationKey = "BANNER_Survival"
	else:
		label.translationKey = "BANNER_10Wins"

	label.updateLocale()

	var delay = 0.8
	Util.callDelayed(subject.bonusAnimation, "play", delay, ["10Wins"])
	if Game.tries == 1:
		subject.triesLeftLabel.text = Util.tra("BANNER_1TryLeft")
	else:
		subject.triesLeftLabel.text = Util.tra("BANNER_xTriesLeft").replace("$num", str(Game.tries))

	subject.bonusTrophyParticles.amount = Game.getBonusTrophies()

static func playRankedAnimation(subject: Receiver):
	subject.rankedAnimation.play("Appear")
	subject.setLeague(Game.leaguePreRun)
	subject.setLeagueProgress(Game.leagueProgressPreRun)

	var newRating: float
	if Game.wasRankedSwitchMode:
		subject.curRanking = Game.getRanking(null)
		newRating = Game.getSwitchModeRating()
		subject.rankedNode.get_node("Class").text = Util.tra("BUTTON_SwitchMode")

	else:
		subject.curRanking = Game.getRanking(Game.curClass)
		newRating = Game.getRunRating(Game.curClass)

	subject.rankingCounter.setCurrent(Game.rankingPreRun)

	var leagueExact = Game.getLeague_exact(newRating)

	var diff = int(leagueExact * 100) - int(Game.leagueExactPreRun * 100)

	if diff < 0:
		subject.rankingDiff.prefix = ""
		subject.rankingDiff.set("theme_override_colors/font_color", Color(0.933594, 0.444916, 0.444916))
	else:
		subject.rankingDiff.prefix = "+"
		subject.rankingDiff.set("theme_override_colors/font_color", Color(0.472865, 0.933594, 0.361038))

	subject.rankingDiff.setCurrent(diff)

	Util.callDelayed(subject, "setNewRanking", 2, [leagueExact])

	Util.callDelayed(subject, "startRunResultSkippable", 1)

static func feedTrophies(subject: Receiver):
	var numTrophies = Game.wins

	var trophies_
	var offset = 0.0
	if Game.curMode == Game.Mode.Lobbies:
		trophies_ = subject.lobbyTrophies
	else:
		trophies_ = subject.trophies

	for i in numTrophies:
		if Game.curMode == Game.Mode.Lobbies:
			offset = Util.rng.randf_range( - 100, 100)
		Util.callDelayed(trophies_[i], "moveToPos", i * subject.TROPHY_DELAY, [subject.chestnutPos.global_position + Vector2(offset, 0)])
		Util.callDelayed(subject, "onTrophyFed", subject.TROPHY_MOVE_DUR + i * subject.TROPHY_DELAY)

	Util.callDelayed(subject, "trophiesFinished", numTrophies * subject.TROPHY_DELAY + 1.5)
	Util.callDelayed(subject.trophyCounter, "setTarget", 0.5, [Game.getTrophies()])

static func setNewRanking(subject: Receiver, leagueExact):

	subject.rankingDiff.setTarget(0)
	subject.barBorderParticles.emitting = true
	subject.emblemParticles.modulate = Game.leagueColors[Game.leaguePreRun].lightened(0.2)

	var progressTween = subject.create_tween()

	var newLeague = int(leagueExact)
	var previousProgress = Game.leagueProgressPreRun
	var newProgress = fmod(leagueExact, 1.0)

	if newLeague > Game.leaguePreRun:
		var dur = (1.0 - previousProgress) * subject.RELATIVE_LEAGUE_BAR_DURATION + subject.BASE_LEAGUE_BAR_DURATION

		progressTween.tween_method(Callable(subject, "setLeagueProgress"), previousProgress, 1.0, dur)
		progressTween.tween_callback(Callable(subject, "updateLeague").bind(newLeague, true, subject.curRanking))

		progressTween.tween_method(Callable(subject, "setLeagueProgress"), 0.0, newProgress, dur).set_delay(0.2)
		subject.emblemParticles.amount = 30
		subject.emblemAnimation.play("IncreasePower")
		subject.rankingCounter.setTarget(100)
		Sound.playSound(subject.rankUpSound)

	elif newLeague < Game.leaguePreRun:
		var dur = previousProgress * subject.RELATIVE_LEAGUE_BAR_DURATION + subject.BASE_LEAGUE_BAR_DURATION

		progressTween.tween_method(Callable(subject, "setLeagueProgress"), previousProgress, 0.0, dur)
		progressTween.tween_callback(Callable(subject, "updateLeague").bind(newLeague, false, subject.curRanking))

		progressTween.tween_method(Callable(subject, "setLeagueProgress"), 1.0, newProgress, dur).set_delay(0.2)
		subject.emblemParticles.amount = 5
		subject.emblemAnimation.play("DecreasePower")
		subject.rankingCounter.setTarget(0)
		Sound.playSound(subject.rankDownSound)

	else:
		var dur = abs(newProgress - previousProgress) * subject.RELATIVE_LEAGUE_BAR_DURATION + subject.BASE_LEAGUE_BAR_DURATION

		progressTween.tween_method(Callable(subject, "setLeagueProgress"), previousProgress, newProgress, dur)
		subject.rankingCounter.setTarget(subject.curRanking)

		if newProgress > previousProgress:
			subject.emblemAnimation.play("IncreasePower")
			Sound.playSound(subject.rankUpSound)
		else:
			subject.emblemAnimation.play("DecreasePower")
			Sound.playSound(subject.rankDownSound)

	progressTween.tween_callback(Callable(subject, "stopParticles"))

static func updateLeague(subject: Receiver, league, rankedUp, ranking):
	subject.setLeague(league)
	var particles
	if rankedUp:
		subject.rankingCounter.setCurrent(0)
		subject.rankUpBonusLabel.text = Util.addPlus(Game.RANK_UP_BONUS_RANKING)
		subject.rankUpBonusAnimation.play("ShowBonus")
		var pulse = ObjectPool.playAnimation(subject.rankUpPulse, "Activate", subject.rankedNode, subject.leagueEmblem)
		pulse.self_modulate = Game.leagueColors[league].lightened(0.2)
		pulse.global_position = subject.leagueEmblem.global_position
		particles = ObjectPool.particleOneShot(subject.rankUpParticles, subject.rankedNode)
		subject.emblemAnimation.play("RankUp")
		Sound.playSound(subject.rankUpSound2, 6)

	else:
		subject.rankingCounter.setCurrent(100)
		particles = ObjectPool.particleOneShot(subject.rankDownParticles, subject.rankedNode)
		subject.emblemAnimation.play("RankDown")

	particles.modulate = Game.leagueColors[league].lightened(0.2)
	particles.global_position = subject.leagueEmblem.global_position
	subject.rankingCounter.setTarget(ranking)

static func reset(subject: Receiver):
	subject.runAnimation.play("RESET")
	subject.roundAnimation.play("RESET")
	subject.rankingDiffAnimation.play("RESET")
	subject.roundIdleAnimation.stop()
	subject.survivalPromptAnimation.play("RESET")
	subject.surviveRoundsCounterAnimation.play("RESET")
	subject.subclassRoundHealAnimation.play("RESET")
	Game.PLAYER.enableClicking()
	subject.phase = subject.Phase.OffScreen
	subject.survivalPromptActive = false
	for trophy in subject.trophies:
		trophy.setEmpty()
	for i in range(10, 20):
		subject.trophies[i].hide()
	subject.postCombatBgmStarted = false

static func hideUI(subject: Receiver):
	subject.UI.hide()
	subject.combatLogButton.disabled = false

	if (Game.getNumStartedRuns() >= 3 and
		Game.getNumStartedRuns() < 10 and
		not Game.isTutorialDone(Game.TutorialSteps.CombatLog)):

		Game.combatLog.tutorialAni.play("Tutorial")

	subject.currentStats.show()
	InputBlocker.restoreAllControls(InputBlocker.Source.CombatUI)
	Game.PLAYER.INVENTORY.enableItemTooltips()
	Game.OPPONENT.INVENTORY.enableItemTooltips()

	subject.clearParticles()

	if subject.survivalPromptActive:
		subject.survivalPrompt.hide()

	if not subject.postCombatBgmStarted:
		subject.postCombatBgmStarted = true
		if Game.survivalMode:
			Sound.playBGM(Sound.postFightBGM_survival, - 3)
		else:
			Sound.playBGM(Sound.postFightBGM, - 4)

static func onShowUI(subject: Receiver):
	subject.currentStats.hide()
	InputBlocker.disableSingleControl(InputBlocker.Source.CombatUI, subject.combatLogButton)

	InputBlocker.disableAllControls(InputBlocker.Source.CombatUI, Game.PLAYER)
	InputBlocker.disableAllControls(InputBlocker.Source.CombatUI, Game.OPPONENT)
	Game.unhoverAndHideTooltips()
	Game.PLAYER.INVENTORY.disableItemTooltips()
	Game.OPPONENT.INVENTORY.disableItemTooltips()
	Game.clearAffectedLines()

static func onCursorWarp(subject: Receiver):
	if not Game.fightEnded:
		for node in subject.combatTimerNodes:
			if Util.isControlEnabled(node):
				Game.addControlOfInterest(node)
	else:
		if subject.hideUIButton.visible:
			Game.addControlOfInterest(subject.hideUIButton)

	if subject.darkLayer.is_visible_in_tree():
		Game.addPointOfInterest(Vector2(960, 960))
	else:
		Game.addControlOfInterest(subject.combatLogButton)

		for character in [Game.PLAYER, Game.OPPONENT]:
			for item in character.INVENTORY.getItemsAndGems():
				Game.addItemOfInterest(item)

			for buffI in character.buffs:
				var buff = character.buffs[buffI]
				if buff.getStacks() > 0:
					Game.addPointOfInterest(buff.counter.global_position + Vector2(20, 20))

			for icon in character.statsDisplay.activeIcons:
				Game.addPointOfInterest(icon.global_position + Vector2(20, 20))
