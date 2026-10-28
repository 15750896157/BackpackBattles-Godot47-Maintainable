extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForZap:
	const Receiver = preload("res://Items/Animations/Zap.gd")

	static func zap(subject: Receiver, startPos: Vector2, endPos: Vector2, style: int):
		subject.global_position = startPos
		var dif = endPos - startPos
		subject.sprite.scale.x = dif.length()
		subject.sprite.scale.y = subject.zapSize[style]
		subject.look_at(endPos)
		subject.sprite.material.set_shader_parameter("frequency", subject.sprite.scale.x * 0.02)
		subject.sprite.material.set_shader_parameter("speed", Util.rng.randf_range(4.0, 4.02))
		subject.animation.play(subject.zapAnis[style])
