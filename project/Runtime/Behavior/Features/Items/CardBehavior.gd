extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Card.gd")

static func canAffect(subject: Receiver, item):
	if subject.placed:
		return (subject.deck and
			item.hasType(subject.Type.Card) and
			(item.chainPosition > subject.chainPosition or item.chainPosition == - 1))
	else:
		return item.hasType(subject.Type.Card) and not item.deck

static func getNextCard(subject: Receiver):

	var affected = subject.getItemsInAffectedCells_cached()
	if not affected.is_empty() and affected[0].hasType(subject.Type.Card):
		return affected[0]
	else:
		return null

static func startActivation(subject: Receiver):
	if subject.activating or subject.faceUp: return

	subject.activating = true
	subject.iterationCooldown = subject.getCooldown()
	subject.triggerTime = subject.iterationCooldown
	subject.activateCooldown()
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown)

static func onStateChanged(subject: Receiver, _faceUp: bool):
	if _faceUp:

		if subject.faceUp:
			subject.cardAnimation.play("JokerReveal")
		else:
			subject.cardAnimation.play("Reveal")
	else:
		if subject.faceUp:
			subject.cardAnimation.play("ShowBack")

	subject.faceUp = _faceUp

static func trigger(subject: Receiver):
	subject.activating = false
	subject.showCooldown(0)
	var nextCard = subject.getNextCard()
	if nextCard:
		nextCard.startActivation()

	subject.triggerTime = subject.iterationCooldown

	subject.setState(true, true)
	subject.deactivateCooldown()
	subject.doRevealEffect()
