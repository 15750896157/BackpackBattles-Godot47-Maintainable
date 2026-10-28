extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Gems/Gem.gd")

static func returnToSocket(subject: Receiver, movebackDur):
	subject.addToSocket(subject.movebackSocket)
	subject.prepareLerpToSocket()
	subject.killDropTween()
	subject.clickArea.hide()
	subject.set_deferred("z_index", 32)
	subject.dropTween = subject.create_tween()
	subject.dropTween.tween_method(Callable(subject, "lerpToSocket"), 0.0, 1.0, movebackDur)
	subject.dropTween.tween_callback(Callable(subject, "resetZ"))
	subject.dropTween.tween_callback(Callable(subject, "showClickArea"))
	subject.movebackSocket = null
