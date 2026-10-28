extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForYggdrasilLeaf:
	const Receiver = preload("res://Items/YggdrasilLeaf.gd")

	static func onManaChanged(subject: Receiver, amount, event: CombatEvent):
		if amount < 0 and event.getParam("used", false):
			subject.manaUsed += - amount
			var activations = subject.manaUsed / subject.manaNeeded
			subject.manaUsed %= subject.manaNeeded
			if activations >= 1:
				subject.heal(subject.getP_m("heal") * activations, event)
				subject.cleanseRandomDebuffs(subject.getP5() * activations, event)
				subject.activate()
