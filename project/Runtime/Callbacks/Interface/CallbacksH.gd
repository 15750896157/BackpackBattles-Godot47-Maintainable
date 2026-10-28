extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForHeart:
	const Receiver = preload("res://Interface/Heart.gd")

	static func heal(subject: Receiver):
		if not subject.isFull:
			var particles = ObjectPool.instantiate(subject.heartRefillParticles)
			subject.add_child(particles)
			particles.restart()
			ObjectPool.returnAfter(1.0, particles)
			subject.animation.play("Heal")
			subject.isFull = true
			Sound.playSound(subject.gainTrySound)
