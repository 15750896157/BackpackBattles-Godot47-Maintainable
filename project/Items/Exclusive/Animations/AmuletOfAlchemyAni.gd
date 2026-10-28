extends "res://Utility/PooledScene.gd"

var particles1
var particles2

func preset():
	particles1 = $GPUParticles2D
	particles2 = $Particles2D2

func moveTo(pos, duration):
	return load("res://Runtime/Callbacks/Items/Exclusive/Animations/CallbacksA.gd").ForAmuletOfAlchemyAni.moveTo(self, pos, duration)

