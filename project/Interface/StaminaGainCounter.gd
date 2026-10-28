extends Label

func _ready() -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForStaminaGainCounter._ready(self)

func updateText():
	text = "+" + str(snapped(Game.PLAYER.getStaminaRegeneration(), 0.1))
