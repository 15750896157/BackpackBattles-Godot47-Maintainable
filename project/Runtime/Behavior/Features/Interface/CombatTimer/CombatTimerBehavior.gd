extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/CombatTimer/CombatTimer.gd")

static func forceMaxSpeed(subject: Receiver):
	subject.pauseButton.hide()
	subject.fastButton.hide()
	subject.speedSlider.modulate = Color(0.5, 0.5, 0.5)
	subject.forceSpeed(subject.MAX_SPEED)

static func onCombatSceneEntered(subject: Receiver):
	subject.speedSlider.editable = true
	subject.pauseButton.disabled = false
	subject.fastButton.disabled = false
	subject.set_physics_process(false)
	subject.set_process_unhandled_input(true)
	Expedition.set_playback(Expedition.flow.combat_speed, Expedition.flow.combat_paused)
	return

static func advanceTime(subject: Receiver, time):
	subject.timeAdvance += time

	var timeLeft = subject.fatigueStartTimer.get_time_left()
	var newTime = timeLeft - time
	if newTime > 0:
		subject.fatigueStartTimer.start(newTime)
	else:
		subject.fatigueStartTimer.stop()

		subject.startFatigue()

	Game.combatLog.snapshotGlobalStat(Game.combatLog.GlobalStat.TimeAdvance, subject.timeAdvance)

static func onSpeedChanged(subject: Receiver, value: float) -> void :
	if subject.speedSlider.editable and subject.pve_combat_active():
		if value > 0.0: subject.speedBeforePause = value
		Expedition.set_playback(maxf(0.25, subject.speedBeforePause), value <= 0.0)
		subject.speedLabel.text = "x0" if value <= 0.0 else "x" + str(value)
	return

static func pause(subject: Receiver):
	if not subject.pve_combat_active(): return
	subject.speedBeforePause = maxf(0.25, Expedition.flow.combat_speed)
	subject.speedSlider.set_value_no_signal(0.0)
	subject.speedLabel.text = "x0"
	Expedition.set_playback(subject.speedBeforePause, true)
	return

static func unpause(subject: Receiver):
	if not subject.pve_combat_active(): return
	subject.speedSlider.set_value_no_signal(maxf(0.25, subject.speedBeforePause))
	subject.speedLabel.text = "x" + str(maxf(0.25, subject.speedBeforePause))
	Expedition.set_playback(maxf(0.25, subject.speedBeforePause), false)
	return

static func onFastButtonPressed(subject: Receiver):
	if not subject.pve_combat_active(): return
	var current = Expedition.flow.combat_speed
	subject.speedSlider.set_value(2.0 if current < 2.0 else 4.0 if current < 4.0 else 1.0)
	Game.onClickButton()
	return

static func pve_combat_active(subject: Receiver) -> bool:
	return Expedition.flow != null and Expedition.flow.screen_state == "COMBAT_RUNNING" and Expedition.native_battle_ready and Game.state == Game.State.Combat
