extends Node2D

signal reroll

const NUM_SEGMENTS = 10
const MAX_PULL = 200.0
const PULL_UP_SPEED = 5.0
const segmentScene = preload("res://Interface/RopeSegment.tscn")

@onready var ropeHolder = $RopeHolder
@onready var line2D = $Line2D
@onready var ropeEndSegment = $End
@onready var tag = $Tag
@onready var tagSprite = $Tag/Tag
@onready var tagAnimation = $Tag/Cost/AnimationPlayer
@onready var tagCostLabel = $Tag/Cost

var segments = []
var joints = []
var jointPositionNodes = []
var jointPositions = []
var draggedSegment = null
var pulledY: float
var rerollReadyTime = 0.0
var hovered = 0
var curEndY = 0

func _ready():
	return load("res://Runtime/Behavior/Interface/PhysicsRopeBehavior.gd")._ready(self)

func onSwitchToShop():
	reset()

func reset():
	rerollReadyTime = Util.time + 0.2
	Game.rerollRope.instancePhysicsRope()

func addSegment(segment):
	return load("res://Runtime/Behavior/Interface/PhysicsRopeBehavior.gd").addSegment(self, segment)

func isGrabbed():
	return draggedSegment != null

func _physics_process(delta):
	return load("res://Runtime/Behavior/Interface/PhysicsRopeBehavior.gd")._physics_process(self, delta)

func getClampedMousePos() -> Vector2:
	return load("res://Runtime/Behavior/Interface/PhysicsRopeBehavior.gd").getClampedMousePos(self)

func gui_input_segment(event, segment):
	return load("res://Runtime/Behavior/Interface/PhysicsRopeBehavior.gd").gui_input_segment(self, event, segment)

func endDrag():
	if draggedSegment != null:

		draggedSegment.endDrag()
	draggedSegment = null
	modulate = Color.WHITE

func onHovered(segment):
	hovered += 1
	modulate = Color(1.2, 1.2, 1.2, 1)

func onHoveredEnd(segment):
	hovered -= 1
	if hovered == 0 and draggedSegment == null:
		modulate = Color.WHITE

func catmull_rom_spline(_points: Array, resolution: int = 10,
	extrapolate_end_points = true) -> Array:
	return load("res://Runtime/Behavior/Interface/PhysicsRopeBehavior.gd").catmull_rom_spline(self, _points, resolution, extrapolate_end_points)

