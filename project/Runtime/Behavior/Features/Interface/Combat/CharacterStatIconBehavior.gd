extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Combat/CharacterStatIcon.gd")

static func setStatValue(subject: Receiver, value):
	if subject.default == null:
		subject.default = value
		return

	if is_equal_approx(value, subject.default):
		if subject.active:
			subject.disappear()
		else:
			pass
	else:
		if subject.active:
			subject.updateLabel(value)

		else:
			subject.appear()
			subject.updateLabel(value)

static func appear(subject: Receiver):
	subject.active = true
	if Game.combatSceneNode.phase != Game.combatSceneNode.Phase.OffScreen:
		subject.show()
		subject.scale = Vector2.ZERO
		subject.tween = Util.refreshTween(subject.tween)
		subject.tween.tween_property(subject, "scale", Vector2.ONE, 0.2)
		subject.tween.set_speed_scale(0)
		subject.set_physics_process(true)

static func disappear(subject: Receiver):
	subject.active = false
	subject.tween = Util.refreshTween(subject.tween)
	subject.tween.tween_property(subject, "scale", Vector2.ZERO, 0.3)
	subject.tween.tween_callback(Callable(subject, "disappeared"))
	subject.tween.set_speed_scale(0)
	subject.set_physics_process(true)

static func _physics_process(subject: Receiver, delta):
	if Util.isTweenRunning(subject.tween):
		subject.tween.set_speed_scale(1)
		subject.tween.custom_step(1 / 60.0)
		subject.tween.set_speed_scale(0)
	else:
		subject.set_physics_process(false)
