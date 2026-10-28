extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/Animations/GooglyEye.gd")

static func _ready(subject: Receiver):
	if not subject.spriteOverride.is_empty():
		subject.sprite = subject.get_node(subject.spriteOverride)

	subject.item = subject.sprite.get_parent()

	subject.set_physics_process(false)

	if subject.item is Item and subject.item.pooled:
		pass
	else:
		subject.call_deferred("ready_deferred")
		Util.callDelayed(subject, "checkRecipeBook", 0.05)

static func _physics_process(subject: Receiver, delta: float) -> void :

	var speedFactor = delta * 60.0

	var curCenterOffset = Vector2.ZERO
	if subject.mouseFollowStrength > 0:
		curCenterOffset = (subject.get_global_mouse_position() - subject.global_position) * subject.mouseFollowStrength
		curCenterOffset = curCenterOffset.rotated( - subject.sprite.global_rotation)

		curCenterOffset = curCenterOffset.limit_length(subject.mouseLimit)

	subject.momentum += (subject.centerWithOffset + curCenterOffset - subject.position) * subject.returnFactor * speedFactor
	subject.momentum *= clamp(1.0 - subject.friction * speedFactor, 0, 1)

	var eyeMovement = subject.oldPos - subject.global_position
	eyeMovement = eyeMovement.rotated(subject.item.global_rotation)
	var unclampedMovement = eyeMovement * subject.movementFactor
	unclampedMovement += subject.momentum * subject.momentumFactor * speedFactor

	var positionCandidate = subject.position + unclampedMovement
	var difFromCenter = positionCandidate - subject.center
	difFromCenter /= subject.aspect
	subject.position = subject.center + difFromCenter.limit_length(subject.eyeRadius) * subject.aspect

	subject.oldPos = subject.global_position
