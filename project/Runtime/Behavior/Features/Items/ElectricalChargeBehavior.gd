extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/ElectricalCharge.gd")

static func returnToObjectPool(subject: Receiver):
	Util.killTween(subject.tween)
	subject.lastChargedItem = null
	subject.curChargedItem = null
	subject.emitterItem = null

	ObjectPool.returnInstance(subject)
	Game.playerNode.remove_child(subject.chargedTileParticles)
	subject.chargedTileVisible = false

static func seek(subject: Receiver, _item, _cells: Array, _duration: float, time: float, stop: bool):
	subject.start(_item, _cells, _duration, true)
	subject.tween.pause()
	subject.tween.custom_step(time)

	if stop:
		subject.tween.stop()
	else:
		subject.tween.play()

static func disappear(subject: Receiver, delay: float):

	subject.tween.tween_property(subject.particles, "scale",
		Vector2.ZERO, subject.FADE_DUR).set_delay(delay)

	subject.tween.tween_property(subject.ballMaterial, "shader_parameter/intensityFactor",
		subject.MIN_INTENSITY, subject.FADE_DUR).set_delay(delay)

	subject.chargedTileParticles.emitting = false
