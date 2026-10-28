extends Label

signal counting_finished

var currentValue: float = 0
var targetValue: int = 0

@onready var animation = $AnimationPlayer

@export var prefix: String = ""
@export var constantSpeed = 0.024 # (float, 0, 0.1, 0.001)
@export var linearSpeed = 0.04 # (float, 0, 0.1, 0.01)

func _ready() -> void :
	set_message_translation(false)

func updateLabel():
	text = prefix + str(roundi(currentValue))

func _physics_process(_delta):
	load("res://Runtime/Callbacks/Interface/CallbacksM.gd").ForMovingCounter._physics_process(self, _delta)

func setTarget(target: int):
	animation.play("RESET")
	targetValue = target
	set_physics_process(true)

func setCurrent(current):

	animation.play("RESET")
	currentValue = current
	updateLabel()
	set_physics_process(false)

func change(amount: int):

	animation.play("RESET")
	targetValue = currentValue + amount

	set_physics_process(true)

func fade():
	animation.play("Hide")

func present():
	animation.play("Present")
