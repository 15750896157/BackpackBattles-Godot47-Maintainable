extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Assets/Decoration/FlowerVase.gd")

static func _on_FlowerVase_button_down(subject: Receiver):

	var remainingTime = Util.getRemainingAnimationTime(subject.animation)
	if remainingTime > 0.2: return
	subject.animation.speed_scale = Util.rng.randf_range(0.9, 1.1)
	if subject.state == 0:
		subject.animation.play("Click")
		Sound.playSound(subject.sound, - 6, 1.3)
	elif subject.state == 1:
		subject.animation.play("Click2")
		Sound.playSound(subject.sound, - 3, 1.1)
	else:
		subject.animation.play("Click3")
		Sound.playSound(subject.sound, 0, 0.9)
	subject.state = (subject.state + 1) % 3

static func _gui_input(subject: Receiver, event):
	if Util.isRightClick(event) and not subject.broken:
		subject.disable()
		subject.broken = true
		subject.animation.stop()

		subject.vase.z_index = 50
		subject.vase.self_modulate.a = 0

		Sound.playSound(subject.shatterSound, 4)

		var particles = ObjectPool.particleOneShot(subject.shatterParticles, subject)
		particles.position = Vector2(47, 107)

		var dur = 2.0
		var targetX = subject.flower.position.x + Util.rng.randf_range( - 500, 1000)
		var peakY = subject.flower.position.y - Util.rng.randf_range(200, 600)
		var timeToPeak = dur * 0.4
		var flowerTween = subject.create_tween().set_parallel()
		flowerTween.tween_property(subject.flower, "position:x", targetX, dur)
		flowerTween.tween_property(subject.flower, "position:y", peakY,
		timeToPeak).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		flowerTween.tween_property(subject.flower, "position:y", 250.0,
			dur - timeToPeak).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_IN).from(peakY).set_delay(timeToPeak)

		flowerTween.tween_property(subject.flower, "rotation",
			Util.rng.randf_range( - 9, 9), dur)

		Game.onDecorationDestructed()
