extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/CraftingBond.gd")

static func _process(subject: Receiver, delta: float) -> void :
	if is_instance_valid(subject.startNode) and is_instance_valid(subject.endNode):
		var startPos = subject.startNode.global_position
		var endPos = subject.endNode.global_position
		var dif = endPos - startPos
		var length = dif.length()
		if length < subject.MIN_LENGTH:
			startPos += Vector2.LEFT * subject.MIN_LENGTH * 0.5
			endPos = startPos + Vector2.RIGHT * subject.MIN_LENGTH * 0.5
			length = subject.MIN_LENGTH
		subject.global_position = startPos
		subject.look_at(endPos)

		Util.stretchSpriteToWidth(subject.sprite, length)
		subject.sprite.material.set_shader_parameter("xStretch", subject.sprite.scale.x * subject.stretchFactor)
		if (subject.startNode.isMovingBack() or subject.endNode.isMovingBack()):
			subject.fadeAcc = 0.0
		else:
			if subject.fadeAcc == 0.0:
				subject.fadeAcc = 0.6
			subject.fadeAcc += delta * 8.0

		subject.sprite.self_modulate.a = clamp(1.0 - (length / 2000), 0.0, 1)
		subject.sprite.self_modulate.a *= clamp(subject.fadeAcc, 0, 1)

static func flash(subject: Receiver):
	subject.tween = Util.refreshTween(subject.tween)
	var flashStrength: float
	if subject.targetStrength == subject.WEAK_STRENGTH:
		flashStrength = 0.3
	elif subject.bondType == subject.BondType.Normal:
		flashStrength = 0.33
	else:
		flashStrength = 0.43

	var flashColor = Color(2, 0.9, 0.9, flashStrength)
	var targetColor = Color(1.2, 1.2, 1.2, subject.targetStrength)
	subject.tween.tween_property(subject.sprite, "modulate", flashColor, 0.07)
	subject.tween.tween_property(subject.sprite, "modulate", targetColor, 0.3).from(flashColor)

static func breakBond(subject: Receiver):
	subject.set_process(false)
	subject.tween = Util.refreshTween(subject.tween)
	var minStrength = subject.MIN_STRENGTH if subject.bondType == subject.BondType.Normal else subject.MIN_STRENGTH_CATALYST
	subject.tween.tween_property(subject.sprite, "modulate:a", minStrength, subject.CHANGE_DUR)
	subject.tween.tween_callback(Callable(subject, "returnToObjectPool"))
