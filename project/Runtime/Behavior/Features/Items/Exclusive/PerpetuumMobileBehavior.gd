extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/PerpetuumMobile.gd")

static func onPrepare(subject: Receiver):
	subject.connectToCharacterBuffs("onBuffChanged")
	for buff in Game.getBuffs():
		subject.usedStacks[buff] = 0.0

	subject.connectForCombat(subject.character(), "character_used_stamina", "onStaminaUsed")
	subject.staminaUsed = 0

	subject.addSpeed(subject.speed * subject.getNumAffectedItems())

static func onBuffChanged(subject: Receiver, amount, event):
	if amount < 0 and event.getParam("used", false):
		var used = - amount
		var buffType = event.getType()
		subject.usedStacks[buffType] += used

static func doCooldownEffect(subject: Receiver):

	for buffType in subject.usedStacks:
		var toRefund = int(round(subject.usedStacks[buffType] * subject.buffRefund))

		if toRefund > 0:
			subject.usedStacks[buffType] -= toRefund
			subject.giveStacks(subject.character(), buffType, toRefund)

	subject.giveStamina(subject.staminaUsed * subject.staminaRefund)
	subject.staminaUsed = 0

	subject.activate()
