extends Sprite2D

@onready var item = get_parent()
@onready var basePos = position.y / scale.y
@onready var spring = $Spring
@onready var springBasePos = spring.position.y
@onready var sockets = $Sockets

@export var speed = 3.0
@export var friction = 0.95
@export var accelFactor = 0.2
@export var maxScale = 0.5
const moveLimit = 30

var squishIntensity = 0.0
var momentum = 0.0
var last_position = Vector2.ZERO
var last_posDif = Vector2.ZERO

func init():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/SpringloaderVisualBehavior.gd").init(self)

func ready_deferred():
	if (item.ownerType == Item.Owner.RecipeBook or
		item.ownerType == Item.Owner.ItemLibrary):
		set_physics_process(false)

func reset():

	squishIntensity = 0.0
	momentum = 0.0
	last_position = global_position
	last_posDif = Vector2.ZERO

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/SpringloaderVisualBehavior.gd")._physics_process(self, delta)

func addMomentum(amount: float):
	if momentum > - 0.001:
		momentum += amount
	else:
		momentum -= amount
