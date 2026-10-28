extends Button
class_name FocusGrabbingButton

@export var playClickSound = true
@export var releaseFocus = true
@export var showOnHover: NodePath = NodePath("")
var hoverReactionNode
var isHovered: bool

func _ready() -> void :
	load("res://Runtime/Behavior/Features/Interface/FocusGrabbingButtonBehavior.gd")._ready(self)

func onHover():
	return load("res://Runtime/Behavior/Features/Interface/FocusGrabbingButtonBehavior.gd").onHover(self)

func onHoverEnd():
	if isHovered:
		isHovered = false
		Util.releaseFocus(self)
		Game.onHoverInteractableEnd(self)
		if hoverReactionNode != null:
			hoverReactionNode.hide()

func onPressed():
	Game.onClickButton()

func enable():
	return load("res://Runtime/Behavior/Features/Interface/FocusGrabbingButtonBehavior.gd").enable(self)

func disable():
	return load("res://Runtime/Behavior/Features/Interface/FocusGrabbingButtonBehavior.gd").disable(self)

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if isHovered and not is_visible_in_tree():
			onHoverEnd()
