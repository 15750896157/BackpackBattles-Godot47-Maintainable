extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Potion.gd")

static func updateConnector(subject: Receiver):
	var affected = subject.getAffectedItems()
	if not affected.is_empty():
		var affectedPoint = subject.getAffectedPoints()[0]
		subject.connector.global_position = affectedPoint
		subject.connector.position.y += 40
		subject.connector.global_rotation = 0

		subject.connector.appear()
		subject.connector.call_deferred("checkState")

		var otherColor = affected[0].potionColor
		var colorDifV = otherColor - subject.potionColor
		var colorDif = abs(colorDifV.r) + abs(colorDifV.g) + abs(colorDifV.b)

		subject.fluid.baseFoaminess = subject.baseFoaminess + 0.2
		subject.fluid.baseScroll = subject.baseScroll + 0.01
		if colorDif > 0.5:
			var newGradient = subject.fluidGradient.duplicate()
			for i in newGradient.get_point_count():
				var offset = newGradient.get_offset(i)
				var color = newGradient.get_color(i)

				if offset < 0.6:
					var brightness = color.gray()

					var newColor = color
					newColor.h = otherColor.h
					newColor.s = otherColor.s
					if brightness > 0.8:
						newColor += color * 0.8
					newColor.a = color.a

					newGradient.set_color(i, newColor)

			subject.fluidGradientTex.gradient = newGradient

	else:
		subject.connector.disappear()
		subject.connector.call_deferred("checkState")
		subject.resetGradient()

static func getStarPosition(subject: Receiver) -> Vector2:
	var cellSize = 2 * subject.halfCellSize.x * subject.global_scale.x
	if subject.faceDirection == subject.FaceDirection.UP or subject.faceDirection == subject.FaceDirection.DOWN:
		return subject.global_position + Vector2(0, - 1.5 * cellSize)
	elif subject.faceDirection == subject.FaceDirection.RIGHT:
		return subject.global_position + Vector2(0.5 * cellSize, - 1.0 * cellSize)
	else:
		return subject.global_position + Vector2( - 0.5 * cellSize, - 1.0 * cellSize)
