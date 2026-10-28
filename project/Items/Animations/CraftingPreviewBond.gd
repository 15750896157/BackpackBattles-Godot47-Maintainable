extends Node2D

const MIN_STRENGTH = 0.15
const CHANGE_DUR = 0.3

var startNode
var endNode
var poolingHandle
var sprite
var tween

func preset():
	sprite = $Sprite2D
	sprite.material.set_shader_parameter("laserSize", MIN_STRENGTH)

func create(_startNode, _endNode, flip):
	return load("res://Runtime/Behavior/Features/Items/Animations/CraftingPreviewBondBehavior.gd").create(self, _startNode, _endNode, flip)

func orient():
	return load("res://Runtime/Behavior/Features/Items/Animations/CraftingPreviewBondBehavior.gd").orient(self)

func _physics_process(delta: float) -> void :
	if is_instance_valid(startNode) and is_instance_valid(endNode):
		orient()

func stopOrientation():
	set_physics_process(false)

func breakBond():
	return load("res://Runtime/Behavior/Features/Items/Animations/CraftingPreviewBondBehavior.gd").breakBond(self)

func returnToObjectPool():
	ObjectPool.returnInstance(self)
