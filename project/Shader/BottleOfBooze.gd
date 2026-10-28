@tool
extends Sprite2D

@export var friction = 0.95
@export var foamDecay = 0.99
@export var backForce = 3.0

@export var momentum = 0.0
@export var baseFoaminess = 0.05
@export var maxFoaminess = 0.9
@export var rotationFoam = 0.05
@export var baseScroll = 0.03
@export var levelModification = 0.0
@export var levelCurve: Curve

@onready var angle = PI / 2 - global_rotation
@onready var last_target_angle = PI / 2 - global_rotation
@onready var last_position = global_position

var targetAngle = 0.0
var foaminess = 0.0
var foamOffset = Vector2(0, 0)
var last_posDif = Vector2.ZERO
var acceleration = Vector2.ZERO

const MAX_MOMENTUM = 0.3

static func angle_to_angle(from, to):
	return fposmod(to - from + PI, PI * 2) - PI

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Shader/BottleOfBoozeBehavior.gd")._physics_process(self, delta)

func createFoam(amount):
	foaminess += amount
