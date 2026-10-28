extends Label

func _ready() -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksM.gd").ForMaxStaminaLabel._ready(self)

func updateText():
	text = String.num(Game.PLAYER.getMaxStamina(), 2).trim_suffix(".0")
