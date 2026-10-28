extends GPUParticles2D

var poolingHandle

func preset():
	pass

func activate(numCoins, startPos, targetPos):
	# Each active burst owns its destination, including overlapping sale flights.
	process_material = process_material.duplicate()
	var direction = Vector3(0, - 1, 0)
	process_material.set_shader_parameter("direction",
		Vector3(direction.x, direction.y, 0))
	process_material.set_shader_parameter("pullCenter", targetPos)
	amount = numCoins
	restart()
