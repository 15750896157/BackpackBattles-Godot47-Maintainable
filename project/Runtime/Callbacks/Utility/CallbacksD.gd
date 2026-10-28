extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForDamageResult:
	const Receiver = preload("res://Utility/DamageResult.gd")

	static func applyDamageReduction(subject: Receiver, amount, item):

		var leftOverDmg = max(0, subject.damage - subject.damageReduction)
		var actualReduction = min(amount, leftOverDmg)
		item.addMetric(Game.ItemMetrics.DamageBlocked, actualReduction)

		subject.damageReduction += amount
