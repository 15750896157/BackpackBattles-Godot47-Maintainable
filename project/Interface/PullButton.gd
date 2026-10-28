extends Button
class_name PullButton

@export var pullVector = Vector2(200, 100)
@export var movebackTime = 0.5

@export var moveBackAfterTrigger = true

@onready var defaultPos = global_position
@onready var endPos = defaultPos + pullVector
@onready var pullLength = pullVector.length()

var grabbed = false
var progress = 0.0
var clickOffset: Vector2

func _ready():
	connect("button_down", Callable(self, "_button_down"))
	connect("button_up", Callable(self, "_button_up"))

func isGrabbed():
	return grabbed

func _button_down():
	if not Game.draggedItem:

		grabbed = true
		clickOffset = Util.getMousePosInWindow() - global_position
		set_physics_process(true)

func _button_up():
	grabbed = false

func _physics_process(delta):
	load("res://Runtime/Callbacks/Interface/CallbacksP.gd").ForPullButton._physics_process(self, delta)

func trigger():
	pass

func deactivate():
	pass

func onHover():
	Util.grabFocus(self)
	Game.onHoverInteractable(self)

func onHoverEnd():
	Util.releaseFocus(self)
	Game.onHoverInteractableEnd(self)
