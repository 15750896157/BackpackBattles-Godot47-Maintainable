
extends Node2D
class_name Eye

@export var friction = 0.04 # (float, 0.0, 1.0)
@export var movementFactor = 0.5 # (float, 0.0, 2.0)
@export var momentumFactor = 0.04 # (float, 0.0, 0.1)
@export var returnFactor = 1.0 # (float, 0.0, 3.0)
@export var eyeRadius = 20.0
@export var mouseFollowStrength = 0.1 # (float, 0.0, 1.0)
@export var aspect: Vector2 = Vector2.ONE
@export var mouseLimit = 5.0 # (float, 0.0, 20.0)
@export var centerOffset: Vector2 = Vector2.ZERO
@export var spriteOverride: NodePath = NodePath("")

@onready var sprite = get_parent()
@onready var oldPos = global_position
var item
@onready var center = position
@onready var centerWithOffset = position + centerOffset

var momentum: Vector2
var disabled = false

func _ready():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/Animations/GooglyEyeBehavior.gd")._ready(self)

func ready_deferred():
	center = position
	centerWithOffset = position + centerOffset
	checkRecipeBook()

func checkRecipeBook():
	if item is Item and item.ownerType == Item.Owner.RecipeBook:
		pass
	else:
		set_physics_process(true)

func _physics_process(delta: float) -> void :
	load("res://Runtime/Behavior/Features/Items/Exclusive/Animations/GooglyEyeBehavior.gd")._physics_process(self, delta)

func focusGlobalPoint(focusPoint: Vector2):
	center = global_position + (focusPoint - global_position) / 50.0

func deactivate():
	set_physics_process(false)

func activate():
	set_physics_process(true)
