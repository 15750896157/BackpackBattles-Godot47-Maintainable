extends Control

@export var keyword: String
@export var highlightingNodes: Array[NodePath] = []
@export var tooltipScene: PackedScene = preload("res://Interface/Tooltips/SimpleTooltip.tscn")

var tooltip
var params = {}
var nameParams = {}
var highlightedNodes = []

func _ready() -> void :
	load("res://Runtime/Behavior/Features/Utility/TooltipAreaBehavior.gd")._ready(self)

func onHover():
	return load("res://Runtime/Behavior/Features/Utility/TooltipAreaBehavior.gd").onHover(self)

func onHoverEnd():
	Game.onHoverInteractableEnd(self)
	hideTooltip()
	for highlightedNode in highlightedNodes:
		if is_instance_valid(highlightedNode):
			highlightedNode.modulate = Color.WHITE

func hideTooltip():
	tooltip.hide()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(tooltip):
			onHoverEnd()
			tooltip.discard()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree() and is_instance_valid(tooltip):
			onHoverEnd()
