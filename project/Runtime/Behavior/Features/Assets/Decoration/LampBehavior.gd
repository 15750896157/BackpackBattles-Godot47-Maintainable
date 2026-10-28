extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Assets/Decoration/Lamp.gd")

static func _physics_process(subject: Receiver, delta):
	subject.rotation_degrees += delta * subject.momentum
	subject.momentum -= subject.rotation_degrees * subject.backForce * delta
	subject.momentum *= subject.friction

	if is_equal_approx(subject.rotation_degrees, 0) and is_equal_approx(subject.momentum, 0):
		subject.set_physics_process(false)

static func onLampPressed(subject: Receiver):
	if subject.momentum > 0:
		subject.momentum += subject.impulse
	else:
		subject.momentum -= subject.impulse
	subject.set_physics_process(true)

	var particles = ObjectPool.particleOneShot(subject.sparkScene1, subject)

	if subject.light.visible:
		if Util.flip(0.1):
			subject.light.hide()
			subject.lamp.modulate = subject.offColor
	else:
		subject.light.show()
		subject.lamp.modulate = Color.WHITE

static func _gui_input(subject: Receiver, event):
	if Util.isRightClick(event) and not subject.broken:
		subject.broken = true
		subject.lamp.disable()
		subject.light.hide()
		subject.lamp.modulate = subject.offColor
		subject.z_index = 50
		subject.momentum = 0

		Sound.playSound(subject.sparkSound)
		var particles = ObjectPool.particleOneShot(subject.sparkScene2, subject)

		var dur = 2.0
		var lampTween = subject.create_tween().set_parallel()
		lampTween.tween_property(subject, "position:y", 1300.0, dur
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lampTween.tween_property(subject, "position:x",
			subject.position.x + Util.rng.randf_range( - 150, 150), dur)
		lampTween.tween_property(subject, "rotation",
			Util.rng.randf_range( - 3.0, 3.0), dur)

		Game.onDecorationDestructed()
