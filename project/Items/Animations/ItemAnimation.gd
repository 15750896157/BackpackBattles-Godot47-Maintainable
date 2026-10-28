extends Node2D

@export var aniName: String = "Attack"
@export var minSpeed: float = 0.8
@export var maxSpeed: float = 1.2
@export var positionRandom: Vector2 = Vector2(30, 100)
@export var angleRandom: float = 5.0
@export var showOnSelf: bool = false

var poolingHandle
var animation
var missAniName: String

func preset():
	return load("res://Runtime/Behavior/Features/Items/Animations/ItemAnimationBehavior.gd").preset(self)

func returnToObjectPool():
	ObjectPool.returnInstance(self)

func randomizePosition():
	return load("res://Runtime/Behavior/Features/Items/Animations/ItemAnimationBehavior.gd").randomizePosition(self)

func intialize(hit: bool):
	return load("res://Runtime/Behavior/Features/Items/Animations/ItemAnimationBehavior.gd").intialize(self, hit)

