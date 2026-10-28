extends Sprite2D
class_name SquishySprite

@onready var item = get_parent()
@onready var baseScale = scale

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
	return load("res://Runtime/Behavior/Features/Items/Animations/SquishySpriteBehavior.gd").init(self)

func ready_deferred():
	if item.ownerType == item.Owner.RecipeBook:
		set_physics_process(false)

	reset()

func reset():
	scale = baseScale
	squishIntensity = 0.0
	momentum = 0.0
	last_position = global_position
	last_posDif = Vector2.ZERO

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Items/Animations/SquishySpriteBehavior.gd")._physics_process(self, delta)

func addMomentum(amount: float):
	if momentum > - 0.001:
		momentum += amount
	else:
		momentum -= amount
