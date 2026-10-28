extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/TooltipArea.gd")

static func _ready(subject: Receiver) -> void :
	subject.tooltip = subject.tooltipScene.instantiate()
	Game.tooltipsNode.add_child(subject.tooltip)
	Game.connect("switch_to_shop", Callable(subject, "hideTooltip"))
	Game.connect("return_to_title", Callable(subject, "hideTooltip"))
	subject.connect("mouse_entered", Callable(subject, "onHover"))
	subject.connect("mouse_exited", Callable(subject, "onHoverEnd"))
	for nodePath in subject.highlightingNodes:
		subject.highlightedNodes.push_back(subject.get_node(nodePath))

static func onHover(subject: Receiver):
	Game.onHoverInteractable(subject)

	var headerText = Util.tra(subject.keyword + "_NAME").format(subject.nameParams)
	var descrText = Util.tra(subject.keyword + "_DESCR").format(subject.params)

	subject.tooltip.setParams(headerText, descrText)

	subject.tooltip.forceUpdatePosition(subject.global_position, subject.size + Vector2(30, 0))
	for highlightedNode in subject.highlightedNodes:
		highlightedNode.modulate = Color(1.3, 1.3, 1.3, 1)
