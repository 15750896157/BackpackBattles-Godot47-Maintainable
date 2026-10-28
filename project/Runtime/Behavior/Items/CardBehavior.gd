extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Card.gd")

static func notifyChainPosition(subject: Receiver, _deck, _chainPos, chainLength):
	subject.chainPosition = _chainPos

	if subject.chainPosition == - 1:
		subject.deck = null
		subject.connector.disappear()
		if subject.placed:
			subject.notInChainMark.appear()
	else:
		subject.deck = _deck
		subject.notInChainMark.disappear()

		if subject.chainPosition != chainLength - 1:
			subject.connector.appear()
		else:
			subject.connector.disappear()

	subject.updateTexture()

	subject.connector.call_deferred("checkState")

static func getCardDescription(subject: Receiver, descr) -> String:
	if subject.deck:
		descr += "\n\n" + subject.insertParameter(Util.tra("CARD_COUNT"), "num", subject.chainPosition, subject.StatModified.No, false)
	elif subject.placed:
		descr += "\n\n" + Util.wrapInColor(Util.tra("CARD_HINT"), Util.paramColor)

	return descr
