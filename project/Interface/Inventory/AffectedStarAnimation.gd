extends "res://Utility/PooledScene.gd"

var animation

func preset():
	super.preset()
	animation = $AnimationPlayer

func _ready():
	animation.play("PopIn")
