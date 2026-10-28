extends "res://Interface/Combat/BlockHud.gd"

@export var activationParticles: PackedScene

func activate():
	var particles = ObjectPool.particleOneShot(activationParticles, get_parent())
	particles.position = position
	particles.scale = sprite.scale
