extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Animations/ItemAnimation.gd")

static func preset(subject: Receiver):
	subject.animation = subject.get_node("AnimationPlayer")
	var character = subject.get_node_or_null("FoxArcher")
	if character:
		character.hide()
		character.queue_free()
	subject.missAniName = subject.aniName + "Miss"

static func randomizePosition(subject: Receiver):
	subject.position.x += Util.rng.randf_range( - subject.positionRandom.x, subject.positionRandom.x)
	subject.position.y += Util.rng.randf_range( - subject.positionRandom.y, subject.positionRandom.y)
	subject.rotation_degrees = Util.rng.randf_range( - subject.angleRandom, subject.angleRandom)

static func intialize(subject: Receiver, hit: bool):
	subject.randomizePosition()

	subject.animation.stop()
	subject.animation.speed_scale = Util.rng.randf_range(subject.minSpeed, subject.maxSpeed)
	if hit:
		subject.animation.play(subject.aniName)
	else:
		subject.animation.play(subject.missAniName)
