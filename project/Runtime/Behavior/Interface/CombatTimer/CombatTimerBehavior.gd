extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/CombatTimer/CombatTimer.gd")

static func initialize(subject: Receiver):
	subject.initButtons()
	subject.speedSlider.max_value = 4.0
	subject.fatigueStartTimer.stop()
	subject.fatigueTickTimer.stop()
	subject.set_physics_process(false)
	subject.timeAdvance = 0.0
	subject.combatTime = 0.0
	subject.speedBeforePause = maxf(0.25, Expedition.flow.combat_speed)
	subject.speedSlider.set_value_no_signal(subject.speedBeforePause)
	subject.speedSlider.editable = true
	subject.pauseButton.disabled = false
	subject.fastButton.disabled = false
	Engine.time_scale = 1.0
	ShaderClock.set_scale(1.0)
	subject.speedLabel.text = "x" + str(subject.speedBeforePause)
	subject.timeLabel.text = "0.0"
	return

static func combatEnd(subject: Receiver):
	subject.fatigueCounter = 0
	subject.fatigueStartTimer.stop()
	subject.fatigueTickTimer.stop()
	Game.fatigueDamageSource.setDamage(0)
	subject.animation.play("HideTimer")
	subject.speedSlider.editable = false
	subject.pauseButton.disabled = true
	subject.fastButton.disabled = true
	subject.fatigueAnimation.play("Hide")
	Engine.time_scale = 1
	ShaderClock.set_scale(Engine.time_scale)
	subject.speedLabel.text = "x1"
	subject.set_physics_process(false)
	subject.set_process_unhandled_input(false)

static func _unhandled_input(subject: Receiver, event):
	if InputBlocker.isActive(): return
	if Expedition.enabled and not subject.pve_combat_active(): return

	if not subject.isMaxSpeedForced():
		if event.is_action_pressed("combat_pause"):
			if Expedition.enabled and Expedition.flow.combat_paused: subject.unpause()
			else: subject.pause()
		elif event.is_action_pressed("combat_play"):
			subject.unpause()
		elif event.is_action_pressed("combat_speed_up"):
			subject.speedUp(0.5)
		elif event.is_action_pressed("combat_speed_down"):
			subject.speedDown(0.5)
