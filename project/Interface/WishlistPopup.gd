extends Node2D

signal closed

@onready var animation = $AnimationPlayer

const openSound = preload("res://Assets/Sound/TurningPage1.wav")

func open():
	Game.UINode.add_child(self)
	Game.pause(Game.PauseSource.Options)
	animation.play("Open")
	Sound.playSound_process(openSound)

func close():
	return await load("res://Runtime/Callbacks/Interface/CallbacksW.gd").ForWishlistPopup.close(self)

