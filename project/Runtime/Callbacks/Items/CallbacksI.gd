extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForItemPushZone:
	const Receiver = preload("res://Items/ItemPushZone.gd")

	static func onBodyEntered(subject: Receiver, body):

		if body is Item:
			var dif = (body.global_position - subject.global_position).normalized()

			body.linear_velocity = (body.linear_velocity.limit_length(200) + dif * 300.3 + Util.mouseVelocity * 50.0).limit_length(500)
			body.angular_velocity += Util.rng.randf_range( - 4, 4)
			body.lastCollisionPos = subject.global_position
