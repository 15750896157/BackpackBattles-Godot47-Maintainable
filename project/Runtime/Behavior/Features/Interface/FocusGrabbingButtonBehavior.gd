extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/FocusGrabbingButton.gd")

static func _ready(subject: Receiver) -> void :

	Util.tryConnect(subject, "mouse_entered", subject, "onHover")
	if subject.releaseFocus:
		Util.tryConnect(subject, "mouse_exited", subject, "onHoverEnd")
	if subject.has_signal("pressed") and subject.playClickSound:
		Util.tryConnect(subject, "pressed", subject, "onPressed")

	if not subject.showOnHover.is_empty():
		subject.hoverReactionNode = subject.get_node(subject.showOnHover)
		subject.hoverReactionNode.hide()

static func onHover(subject: Receiver):
	if not Game.itemListOpened:
		subject.isHovered = true
		Util.grabFocus(subject)
		Game.onHoverInteractable(subject)
		if subject.hoverReactionNode != null:
			subject.hoverReactionNode.show()

static func enable(subject: Receiver):
	subject.disabled = false
	subject.focus_mode = Control.FOCUS_ALL
	Util.tryConnect(subject, "mouse_entered", subject, "onHover")
	if subject.releaseFocus:
		Util.tryConnect(subject, "mouse_exited", subject, "onHoverEnd")

static func disable(subject: Receiver):
	subject.disabled = true
	subject.focus_mode = Control.FOCUS_NONE

	Util.tryDisconnect(subject, "mouse_entered", subject, "onHover")
	if subject.releaseFocus:
		Util.tryDisconnect(subject, "mouse_exited", subject, "onHoverEnd")
