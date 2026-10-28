extends AnimationPlayer

func _process(delta):
	if Engine.time_scale == 0:
		speed_scale = 0
	else:
		speed_scale = 1 / Engine.time_scale
