extends LocalizedControl

@onready var icon = $StaminaUsage
@onready var animation = $AnimationPlayer
@onready var tooltipArea = $TooltipArea

var updateQueued = false

const colors = [
	Color(0.664886, 1, 0.457031),
	Color(0.893951, 1, 0.457031),
	Color(1, 0.97879, 0.457031),
	Color(1, 0.686096, 0.457031),
	Color(1, 0.390625, 0.390625)
]

func _ready() -> void :
	super._ready()
	add_to_group("Localized")
	Game.connect("inventory_changed", Callable(self, "updateCounter"))

func updateCounter():
	if not updateQueued:
		updateQueued = true
		call_deferred("updateLocale")

func updateLocale():
	return load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForStaminaUseCounter.updateLocale(self)

