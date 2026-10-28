extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForNameLineEdit:
	const Receiver = preload("res://Interface/NameLineEdit.gd")

	static func _ready(subject: Receiver) -> void :
		subject.set_physics_process(false)

		subject.connect("text_changed", Callable(subject, "onTextChanged"))
		subject.connect("mouse_entered", Callable(subject, "onHover"))
		subject.connect("mouse_exited", Callable(subject, "onHoverEnd"))
		subject.connect("focus_exited", Callable(subject, "onFocusLost"))

		Util.localizeFonts(subject)
		subject.add_to_group("Localized")
		subject.updateLocale()
