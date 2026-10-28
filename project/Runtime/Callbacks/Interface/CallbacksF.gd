extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForFocusGrabbingControl:
	const Receiver = preload("res://Interface/FocusGrabbingControl.gd")

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
