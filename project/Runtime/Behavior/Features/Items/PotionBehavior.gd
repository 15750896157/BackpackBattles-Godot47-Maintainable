extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Potion.gd")

static func fill(subject: Receiver):
	subject.isFull = true
	Util.killTween(subject.fluidTween)
	subject.fluidTween = subject.create_tween()
	subject.fluidTween.tween_property(subject.fluid, "levelModification", 0.0, subject.baseLevel + 0.5)

static func is_empty(subject: Receiver):
	subject.isFull = false
	Util.killTween(subject.fluidTween)
	subject.fluidTween = subject.create_tween()
	subject.fluidTween.tween_property(subject.fluid, "levelModification", subject.baseLevel - 1.0, subject.baseLevel + 0.5)
	Sound.playSound(subject.drinkSound)

static func consumePotion(subject: Receiver, event, withActivate: bool):
	if subject.isEmpty(): return

	subject.drink()

	subject.triggerPotion(event)

	var affected = subject.getAffectedItems()
	if not affected.is_empty():
		affected[0].triggerPotion()
		affected[0].miniActivate()

	if withActivate:
		subject.activate()

static func getAffectedCellsAfterRotate_primary(subject: Receiver, rotatedCells) -> Array:

	if subject.faceDirection == subject.FaceDirection.DOWN:
		return [rotatedCells[1] + Vector2.UP]
	else:
		return [rotatedCells[0] + Vector2.UP]
