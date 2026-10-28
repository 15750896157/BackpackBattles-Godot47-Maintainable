extends RigidBody2D

var LENGTH = 50
const WIDTH = 100
@onready var start = $Start
@onready var end = $End

@onready var collisionShape = $CollisionShape2D
@onready var clickArea = $ClickArea

var rope
var hovered: bool = false
var dragged: bool = false
var startTransform: Transform2D
var resetPending: bool = false

@export var ending = false

func _ready():
	load("res://Runtime/Callbacks/Interface/CallbacksR.gd").ForRopeSegment._ready(self)

func ready_deferred():
	startTransform = global_transform

func getLength():
	if ending:
		return end.position.y - start.position.y
	return LENGTH

func getStartPos() -> Vector2:
	return position + start.position

func getEndPos() -> Vector2:
	return position + end.position

func onMouseEntered():
	hovered = true
	rope.onHovered(self)

func onMouseExited():
	hovered = false
	rope.onHoveredEnd(self)

func startDrag():
	sleeping = false
	dragged = true

func endDrag():
	dragged = false

func _integrate_forces(state: PhysicsDirectBodyState2D):
	load("res://Runtime/Callbacks/Interface/CallbacksR.gd").ForRopeSegment._integrate_forces(self, state)

func reset():
	resetPending = true
