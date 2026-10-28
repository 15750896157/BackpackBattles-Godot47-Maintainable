extends Node2D

@onready var staminaMat = $Bar.material
@onready var label = $Label
@onready var character = get_parent().get_parent()

var displayRelStamina: float

func _ready() -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForStaminabar._ready(self)

func onEnteringCombat():
	resetBar()
	set_process(true)

func onCombatLeft():
	set_process(false)

func resetBar():
	staminaMat.set_shader_parameter("lastDamagePercentage", 1)
	staminaMat.set_shader_parameter("healthPercentage", 1)
	displayRelStamina = 1.0

func ready_deferred():
	updateNumber()

func _process(_delta: float) -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForStaminabar._process(self, _delta)

func updateNumber():
	var currentStamina = Util.floorStepify(character.curStamina, 0.1)
	label.text = str(currentStamina, "/", snapped(character.getMaxStamina(), 0.1))
