extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/SpringloaderVisual.gd")

static func init(subject: Receiver):

	if subject.item.pooled and subject.item.ownerType != Item.Owner.Title:
		subject.reset()
		subject.set_physics_process(false)
	else:
		subject.call_deferred("ready_deferred")
		Util.callDelayed(subject, "ready_deferred", 0.05)
		subject.set_physics_process(true)

static func _physics_process(subject: Receiver, delta):

	var oversize = subject.squishIntensity < - subject.maxScale or subject.squishIntensity > subject.maxScale
	var posDif = subject.last_position - subject.item.global_position

	posDif = posDif.limit_length(subject.moveLimit)
	var acceleration = posDif - subject.last_posDif

	acceleration = acceleration.project(Vector2.UP.rotated(subject.global_rotation))
	var strength = acceleration.rotated( - subject.global_rotation).y

	subject.last_posDif = posDif
	subject.last_position = subject.item.global_position

	var curAccel = subject.accelFactor
	if subject.item.liesInStorage():
		curAccel *= 1.5

	subject.momentum += strength * curAccel * delta

	if oversize:
		if sign(subject.squishIntensity) != sign(subject.momentum):
			subject.momentum *= - 0.05

	subject.momentum += subject.squishIntensity * delta * subject.speed

	subject.momentum *= subject.friction
	subject.squishIntensity -= subject.momentum

	var displacement = 100 * subject.squishIntensity
	subject.offset.y = subject.basePos + displacement * 2.0
	subject.sockets.position.y = subject.offset.y

	subject.spring.scale.y = 0.9 - displacement / 225.0
	subject.spring.scale.x = lerp(1.0, 1.0 / subject.spring.scale.x, 0.5)

	subject.spring.position.y = subject.springBasePos + subject.basePos + displacement
