extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForAffectsLine:
	const Receiver = preload("res://Items/Exclusive/Animations/AffectsLine.gd")

	static func setPositions(subject: Receiver, item, end: Vector2):
		var start: Vector2 = item.global_position

		var minDist = 99999.9
		for cellPos in item.getCollisionPoints():
			var dist = cellPos.distance_to(end)
			if dist < minDist:
				start = cellPos
				minDist = dist

		var dif = start - end
		var dir = dif.normalized()
		subject.sortLength = dif.length()

		end = start - dir * (40 + subject.sortLength / 7)

		subject.position = end
		subject.line.points[0] = dir * 0.0
		subject.line.points[1] = (start - end) - dir * 30.0

		subject.star.position = subject.line.points[0]
		subject.star.look_at(subject.star.global_position + dif)

class ForAmuletOfAlchemyAni:
	const Receiver = preload("res://Items/Exclusive/Animations/AmuletOfAlchemyAni.gd")

	static func moveTo(subject: Receiver, pos, duration):
		var tween = subject.create_tween()
		subject.particles1.emitting = true
		tween.tween_property(subject, "global_position", pos, duration)
		tween.tween_callback(Callable(subject.particles1, "set_emitting").bind(false))
		tween.tween_callback(Callable(subject.particles2, "restart"))
		tween.tween_callback(Callable(subject, "returnToObjectPool")).set_delay(subject.particles1.lifetime)
