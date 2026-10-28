extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForDeathScythe:
	const Receiver = preload("res://Items/DeathScythe.gd")

	static func onOpponentPoisonChanged(subject: Receiver, _amount, _event):
		var curPoison = subject.opponent().getPoison()

		if not subject.critBonusActive and curPoison >= subject.poisonThreshold:
			subject.setState(true)
			subject.changeCritChancePercent(subject.getChance())
			subject.activationParticles.activate()

class ForDemonicFlask:
	const Receiver = preload("res://Items/DemonicFlask.gd")

	static func onDamaged(subject: Receiver, healthChange, event):
		if subject.isEmpty(): return

		if subject.opponent().getRelativeHealth() < subject.healthThreshold:

			subject.drink()

			subject.triggerPotion(event)

			var affected = subject.getAffectedItems()
			if not affected.is_empty():
				affected[0].triggerPotion(event)
				affected[0].miniActivate()

			subject.activate()
