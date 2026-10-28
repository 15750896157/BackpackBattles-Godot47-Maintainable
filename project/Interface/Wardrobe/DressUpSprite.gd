extends Node2D

@onready var character = get_parent().get_parent().get_parent()

var idleAnimationPlayers = []

func _ready():
	findIdleAnis(self)

func findIdleAnis(node):
	return load("res://Runtime/Behavior/Interface/Wardrobe/DressUpSpriteBehavior.gd").findIdleAnis(self, node)

func setSkin(slot: int, skinId: int):
	return load("res://Runtime/Behavior/Interface/Wardrobe/DressUpSpriteBehavior.gd").setSkin(self, slot, skinId)

func syncIdleAnis():
	return load("res://Runtime/Behavior/Interface/Wardrobe/DressUpSpriteBehavior.gd").syncIdleAnis(self)

var slotNodes = []

func searchNodes(slot, rootNode):
	slotNodes.clear()
	visitNode(slot, rootNode)
	return slotNodes.duplicate()

func visitNode(slot, node):
	return load("res://Runtime/Behavior/Interface/Wardrobe/DressUpSpriteBehavior.gd").visitNode(self, slot, node)

