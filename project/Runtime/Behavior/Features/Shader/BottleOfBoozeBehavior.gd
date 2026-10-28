extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Shader/BottleOfBooze.gd")

static func _physics_process(subject: Receiver, delta):

	var speedScale = delta * 60.0
	subject.targetAngle = - subject.global_rotation + PI / 2

	var posDif = subject.last_position - subject.global_position
	posDif = posDif.limit_length(50)
	subject.acceleration = posDif - subject.last_posDif
	subject.momentum += subject.acceleration.x * 0.0015 * speedScale
	subject.foaminess += (subject.acceleration.x * 0.001 + subject.acceleration.y * 0.002) * speedScale

	subject.last_posDif = posDif
	subject.last_position = subject.global_position

	var angleChange = subject.angle_to_angle(subject.targetAngle, subject.angle)
	subject.foaminess = clamp(subject.foaminess * subject.foamDecay + angleChange * subject.rotationFoam, 0, subject.maxFoaminess)
	subject.last_target_angle = subject.targetAngle

	var angleDiff = subject.angle_to_angle(subject.targetAngle, subject.angle)
	subject.momentum -= angleDiff * subject.backForce * delta
	subject.momentum *= 1 - ((1 - subject.friction) * speedScale)
	subject.angle = fposmod(subject.angle, 2 * PI)
	subject.targetAngle = fposmod(subject.targetAngle, 2 * PI)

	subject.momentum = clamp(subject.momentum, - subject.MAX_MOMENTUM, subject.MAX_MOMENTUM)

	subject.angle += subject.momentum * speedScale
	subject.foamOffset += Vector2.DOWN * 0.01 * (subject.foaminess + subject.baseScroll) * speedScale

	var screenUV = subject.global_position / Vector2(1920, 1080) * Vector2(1, - 1)

	var totalLevel = subject.levelModification
	totalLevel += subject.levelCurve.sample(fposmod(subject.angle / (PI * 2) - 0.25, 1))

	subject.material.set_shader_parameter("levelOffset", totalLevel)
	subject.material.set_shader_parameter("angle", subject.angle)
	subject.material.set_shader_parameter("foaminess", subject.foaminess + subject.baseFoaminess)
	subject.material.set_shader_parameter("foamOffset", subject.foamOffset + screenUV)
