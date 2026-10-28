extends Node2D

const AffectsInside = 6

const secondPos = Vector2(21, 6)
const thirdPos = Vector2( - 21, 6)

var poolingHandle
var sprites: Dictionary

func _process(delta):
	global_rotation = 0

func preset():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Animations/CanAffectVisualBehavior.gd").preset(self)

func setColorActive(color):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Animations/CanAffectVisualBehavior.gd").setColorActive(self, color)

func returnToObjectPool():
	for color in sprites:
		sprites[color].hide()
	ObjectPool.returnInstance(self)
