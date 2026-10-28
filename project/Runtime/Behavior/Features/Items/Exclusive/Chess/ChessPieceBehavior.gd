extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/Chess/ChessPiece.gd")

static func onPieceCaptured(subject: Receiver, eliminatedPiece, activateEvent):
	subject.numCaptures += 1
	var targetCell = eliminatedPiece.occupiedCells[0]
	subject.inventory.clearItemCells(eliminatedPiece)

	subject.setState(targetCell, false, activateEvent)
	Sound.playSound(subject.captureSounds.pick_random(), 0, Util.randPitch())
	var event = subject.doCapturingEffect(eliminatedPiece)
	return event

static func onEliminatedBy(subject: Receiver, capturingPiece, activateEvent):
	subject.setState(true, false, activateEvent)
	subject.doEliminatedEffect(capturingPiece)
	var particles = ObjectPool.instantiate(subject.destroyParticlesScene)
	subject.get_parent().add_child(particles)
	particles.global_position = subject.global_position
	var direction = (subject.global_position - capturingPiece.sprite.global_position).normalized() * 1200
	particles.activate(subject.sprite, direction)

static func repositionPiece(subject: Receiver, toCell):
	subject.z_index = 3
	subject.moveTo(subject.global_position, subject.inventory.cellToGlobalPos(toCell, true), 0.3)
	subject.inventory.moveItem(subject, [toCell])
	subject.movebackTween.tween_callback(Callable(subject, "resetZ"))

static func onStateChanged(subject: Receiver, state):
	if typeof(state) == TYPE_VECTOR2:
		var targetCell = state
		subject.repositionPiece(targetCell)
		subject.show()

	else:
		subject.captured = state
		if subject.captured:
			subject.hide()

			subject.inventory.clearItemCells(subject)
		else:
			subject.show()

static func onAddToInventory(subject: Receiver):
	if subject.noBoardMark == null:
		subject.noBoardMark = ObjectPool.instantiate(subject.noBoardMarkScene)
		subject.add_child(subject.noBoardMark)
		subject.noBoardMark.scale = Vector2(0.8, 0.8)

	if subject.board == null:
		subject.noBoardMark.appear()
