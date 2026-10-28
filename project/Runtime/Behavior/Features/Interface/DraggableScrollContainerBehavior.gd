extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DraggableScrollContainer.gd")

static func _ready(subject: Receiver):
	subject.scrollBar.connect("mouse_entered", Callable(subject, "onScrollbarHover"))
	subject.scrollBar.connect("mouse_exited", Callable(subject, "onScrollbarHoverEnd"))
	subject.set_process(false)
	subject.set_process_input(false)

static func _process(subject: Receiver, delta):
	if Util.isActionPressed("ui_accept", false):
		var leftBorder = subject.scrollBar.global_position.y + subject.margin
		var size = (subject.scrollBar.size.y * subject.scrollBar.scale.y) - 2 * subject.margin
		var valueRange = subject.scrollBar.max_value - subject.scrollBar.min_value
		var relPos = (subject.get_global_mouse_position().y - leftBorder) / size
		subject.scrollBar.value = subject.scrollBar.min_value + (valueRange * relPos)

static func _input(subject: Receiver, event):
	if event is InputEventMouseButton and event.pressed and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			subject.emit_signal("zoomed", - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			subject.emit_signal("zoomed", 1)
