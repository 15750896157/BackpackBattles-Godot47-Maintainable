extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Animations/SquishySprite.gd")

static func init(subject: Receiver):

	if subject.item.pooled and subject.item.ownerType != subject.item.Owner.Title:
		subject.reset()
		subject.set_physics_process(false)
	else:
		subject.call_deferred("ready_deferred")
		Util.callDelayed(subject, "ready_deferred", 0.05)
		subject.set_physics_process(true)

static func _physics_process(subject: Receiver, delta):

	var oversize = subject.squishIntensity < - subject.maxScale or subject.squishIntensity > subject.maxScale
	var posDif = subject.last_position - subject.global_position

	posDif = posDif.limit_length(subject.moveLimit)
	var acceleration = posDif - subject.last_posDif

	subject.last_posDif = posDif
	subject.last_position = subject.global_position

	var curAccel = subject.accelFactor
	if subject.item.liesInStorage():
		curAccel *= 1.5

	if abs(acceleration.x) > abs(acceleration.y):
		subject.momentum += acceleration.length() * curAccel * delta * sign(acceleration.x)
	else:
		subject.momentum -= acceleration.length() * curAccel * delta * sign(acceleration.y)

	if oversize:
		if sign(subject.squishIntensity) != sign(subject.momentum):
			subject.momentum *= - 0.05

	subject.momentum += subject.squishIntensity * delta * subject.speed

	subject.momentum *= subject.friction
	subject.squishIntensity -= subject.momentum

	subject.scale = subject.baseScale

	if subject.squishIntensity > 0:
		var x_scale = 1 + subject.squishIntensity
		var y_scale = 1.0 / x_scale
		subject.scale *= Vector2(x_scale, y_scale)
	else:
		var y_scale = 1 - subject.squishIntensity
		var x_scale = 1.0 / y_scale
		subject.scale *= Vector2(x_scale, y_scale)
