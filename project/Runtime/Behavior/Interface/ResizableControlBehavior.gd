extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/ResizableControl.gd")

static func _process(subject: Receiver, delta):
	if subject.verticalResizing:
		var globalEndPos = Util.clampToScreen(subject.get_global_mouse_position() + subject.resizeOffset)
		subject.size.y = globalEndPos.y - subject.global_position.y

	elif subject.horizontalResizing:
		var globalEndPos = Util.clampToScreen(subject.get_global_mouse_position() + subject.resizeOffset)
		subject.size = globalEndPos - subject.global_position

	elif subject.dragPosition != null:
		var topLeftPoint = subject.get_global_mouse_position() - subject.dragPosition
		subject.global_position = Util.clampToScreen(topLeftPoint)
		subject.global_position = Util.clampToScreen(subject.global_position + subject.size) - subject.size
		if subject.global_position.distance_to(subject.globalDragStartPosition) > 10:
			subject.movedDuringDrag = true

static func _input(subject: Receiver, event: InputEvent) -> void :
	if (subject.is_visible_in_tree() and
		not subject.verticalResizing and
		not subject.horizontalResizing and
		(subject.Input.get_current_cursor_shape() == subject.CURSOR_ARROW or
			subject.Input.get_current_cursor_shape() == subject.CURSOR_POINTING_HAND)):

		if (Util.isAction_event(event, "grab_item") or event is InputEventScreenTouch):
			if event.is_pressed():
				var clickPos = subject.get_global_mouse_position()
				var rect = subject.get_global_rect()
				if rect.has_point(clickPos):
					if subject.canDrag():
						subject.dragging = true
						if subject.draggable:
							subject.startDragging()
						subject.emit_signal("drag_start")

	if ((Util.isAction_event(event, "grab_item") or event is InputEventScreenTouch)
		and not event.is_pressed()):
		subject.verticalResizing = false
		subject.horizontalResizing = false
		subject.set_process(false)
		if subject.dragging:
			subject.dragging = false
			if subject.draggable:
				subject.endDragging()
			subject.emit_signal("drag_end")

static func _ready(subject: Receiver) -> void :
	subject.set_process(false)
	subject.set_process_input(false)

	if subject.vResizeButton:
		subject.vResizeButton.connect("button_down", Callable(subject, "onVerticalResizeButtonDown"))

	if subject.hResizeButton:
		subject.hResizeButton.connect("button_down", Callable(subject, "onHorizontalResizeButtonDown"))
