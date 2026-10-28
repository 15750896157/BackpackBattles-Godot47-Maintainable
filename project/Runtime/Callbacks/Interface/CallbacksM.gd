extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForMaxStaminaLabel:
	const Receiver = preload("res://Interface/MaxStaminaLabel.gd")

	static func _ready(subject: Receiver) -> void :
		Game.PLAYER.connect("class_changed", Callable(subject, "updateText"))
		Game.PLAYER.connect("max_stamina_changed_ui", Callable(subject, "updateText"))
		subject.updateText()

class ForMovingCounter:
	const Receiver = preload("res://Interface/MovingCounter.gd")

	static func _physics_process(subject: Receiver, _delta):
		var dif: float = subject.targetValue - subject.currentValue

		if abs(dif) < 1:
			subject.currentValue = subject.targetValue

			subject.emit_signal("counting_finished")
			subject.set_physics_process(false)
		else:
			var step = subject.linearSpeed * dif + sign(dif) * subject.constantSpeed
			subject.currentValue += step

		subject.updateLabel()
