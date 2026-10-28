extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/PuzzlebagT.gd")

static func onPrepare(subject: Receiver):
	subject.affectedInside = subject.getAffectedItemsInside()
	if not subject.affectedInside.is_empty():
		subject.connectToCharacterBuffs("onBuffChanged")
		for buff in Game.getBuffs():
			subject.usedStacks[buff] = 0.0

static func onBuffChanged(subject: Receiver, amount, event):
	if (amount < 0 and event.getParam("used", false) and
		event.origin in subject.affectedInside):
		var used = - amount
		var buffType = event.getType()
		subject.usedStacks[buffType] += used * subject.refund
		var toRefund = int(round(subject.usedStacks[buffType]))

		if toRefund > 0:
			subject.usedStacks[buffType] -= toRefund
			subject.giveStacks(subject.character(), buffType, toRefund, event)
			subject.miniActivate()

static func getBagEffect(subject: Receiver, number):
	var descr = Util.tra(subject.getName() + "_BAGEFFECT")
	descr = subject.insertParameter(descr, "p_buff", subject.getP("buff") * number)
	return descr
