extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForPotionConnector:
	const Receiver = preload("res://Items/Animations/PotionConnector.gd")

	static func _physics_process(subject: Receiver, _delta: float) -> void :
		if subject.potion.placed:
			var affected = subject.potion.getAffectedItems()
			if not affected.is_empty():
				var affectedPoint = subject.potion.getStarPosition()
				subject.global_position = affectedPoint
				subject.position.y += 40 * subject.potion.global_scale.x
				subject.global_rotation = 0
				subject.global_scale = subject.startScale * subject.potion.global_scale

		subject.z_index = Util.getGlobalZ(subject.potion)
