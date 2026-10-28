extends Node2D

@onready var boxVisual = $BoxVisual
@onready var area = $Area2D
@onready var collisionShape = $Area2D/CollisionShape2D

var withoutBags: bool
var startPoint: Vector2
var selectedInventoryItems: Array
var selectedStorageItems: Array
var spaceStateQuery: PhysicsShapeQueryParameters2D
var grabbingShape = CircleShape2D.new()
var startFrame: int
var startedWithLeftClick: bool

var closestItem = null

func _ready():
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd")._ready(self)

func canStart() -> bool:
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd").canStart(self)

func _input(event):
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd")._input(self, event)

func _unhandled_input(event):
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd")._unhandled_input(self, event)

func startSelecting():
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").startSelecting(self)

func findAndPickCloseItem(radius = 80.0):
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").findAndPickCloseItem(self, radius)

func findCloseItem(radius = 80.0):
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").findCloseItem(self, radius)

func findTouchedItems(atPos) -> Array:
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd").findTouchedItems(self, atPos)

func getScore(item):
	if item.isGem() and item.socket:
		return 2
	elif item.isBag():
		return 0
	else:
		return 1

func findTouchedItem(atPos):
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd").findTouchedItem(self, atPos)

func canPickFromInventory(item) -> bool:
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").canPickFromInventory(self, item)

func canPickFromStorage(item) -> bool:
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").canPickFromStorage(self, item)

func onItemAreaEntered(itemArea):
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd").onItemAreaEntered(self, itemArea)

func onItemAreaExited(itemArea):
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").onItemAreaExited(self, itemArea)

func cancel():
	for item in selectedInventoryItems:
		item.resetBright()
	end()

func end():
	return load("res://Runtime/Behavior/Features/Interface/SelectionBoxBehavior.gd").end(self)

const BOTTOM_RIGHT_BORDER = Vector2(1920, 1080)

func _process(delta):
	return load("res://Runtime/Behavior/Interface/SelectionBoxBehavior.gd")._process(self, delta)

