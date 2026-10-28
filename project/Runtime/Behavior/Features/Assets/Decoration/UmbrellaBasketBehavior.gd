extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Assets/Decoration/UmbrellaBasket.gd")

static func _on_UmbrellaBasket_button_down(subject: Receiver):
	var remainingTime = 0
	if subject.animation.is_playing():
		remainingTime = subject.animation.current_animation_length - subject.animation.current_animation_position

	if remainingTime > 0.15: return
	subject.animation.speed_scale = Util.rng.randf_range(0.9, 1.3)
	if subject.state == 0:
		subject.animation.play("Click1")
	else:
		subject.animation.play("Click2")
	subject.state = (subject.state + 1) % 2
	Sound.playSound(subject.sound, - 10)

static func _gui_input(subject: Receiver, event):
	if Util.isRightClick(event) and not subject.broken:
		subject.broken = true
		subject.animation.stop()

		Sound.playSound(subject.flySound)

		var dur = 2.0
		var targetX = Util.rng.randf_range( - 2600, - 1700)
		var peakY = subject.umbrella.position.y - Util.rng.randf_range(400, 900)
		var targetY = 500.0
		var timeToPeak = dur * 0.4

		var umbrellaTween = subject.create_tween().set_parallel()
		umbrellaTween.tween_property(subject.umbrella, "position:x", targetX, dur)
		umbrellaTween.tween_property(subject.umbrella, "position:y", peakY,
			timeToPeak).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		umbrellaTween.tween_property(subject.umbrella, "position:y", targetY,
			dur - timeToPeak).set_delay(timeToPeak).set_trans(
			Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).from(peakY)

		umbrellaTween.tween_property(subject.umbrella, "rotation",
			Util.rng.randf_range( - 27, - 9), dur)

		umbrellaTween.tween_property(subject.umbrella, "z_index", 50, 0.01).set_delay(0.05)

		Game.onDecorationDestructed()
