extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForTooltipLabel:
	const Receiver = preload("res://Interface/TooltipLabel.gd")

	static func positionLabel(subject: Receiver, control, offset):
		subject.global_position = control.global_position
		subject.global_position.x += control.size.x * 0.5
		subject.global_position.x -= subject.size.x * 0.5
		subject.global_position += offset

		var difToRightBorder = subject.RIGHT_BORDER - (subject.global_position.x + subject.size.x)
		if difToRightBorder < 0:
			subject.global_position.x += difToRightBorder

		var difToTopBorder = subject.TOP_BORDER - subject.global_position.y
		if difToTopBorder > 0:
			subject.global_position.y += difToTopBorder

class ForTrophy:
	const Receiver = preload("res://Interface/Trophy.gd")

	static func moveToPos(subject: Receiver, pos: Vector2):
		subject.animation.play("Move")

		subject.trailParticles.activate()
		var tween = subject.create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(subject.trophy, "global_position", pos, 1.0)
		tween.tween_callback(Callable(subject.trail, "stop")).set_delay(2)
		tween.tween_callback(Callable(subject.trailParticles, "deactivate"))
		Sound.playRising(subject.moveSound)
		Util.callDelayed(Sound, "playRising", 1.0, [subject.arriveSound])

class ForTugofWarAnimation:
	const Receiver = preload("res://Interface/TugofWarAnimation.gd")

	static func _physics_process(subject: Receiver, delta):
		if not is_instance_valid(Game.PLAYER) or not is_instance_valid(Game.OPPONENT) or not is_instance_valid(subject.oppoSword):
			subject.set_physics_process(false)
			return
		var playerStrength = Game.PLAYER.getCurrentHealth()
		if playerStrength > 0:
			playerStrength += Game.PLAYER.getBlock()
		playerStrength = max(playerStrength, 0)

		var oppoStrength = Game.OPPONENT.getCurrentHealth()
		if oppoStrength > 0:
			oppoStrength += Game.OPPONENT.getBlock()
		oppoStrength = max(oppoStrength, 0)

		if playerStrength == 0 and oppoStrength == 0:
			playerStrength = 1

		var playerAdvantage = float(playerStrength) / (playerStrength + oppoStrength)
		subject.displayAdvantage = lerp(subject.displayAdvantage, playerAdvantage, subject.STEP)

		var offsetAdvantage = subject.displayAdvantage - 0.5

		if offsetAdvantage > 0:
			subject.rotation_degrees = subject.startRot + offsetAdvantage * subject.MAX_ANGLE
			subject.oppoSword.rotation_degrees = subject.oppoStartRot + offsetAdvantage * subject.MAX_ANGLE * subject.DISADVANTAGE_FACTOR
		else:
			subject.rotation_degrees = subject.startRot + offsetAdvantage * subject.MAX_ANGLE * subject.DISADVANTAGE_FACTOR
			subject.oppoSword.rotation_degrees = subject.oppoStartRot + offsetAdvantage * subject.MAX_ANGLE
