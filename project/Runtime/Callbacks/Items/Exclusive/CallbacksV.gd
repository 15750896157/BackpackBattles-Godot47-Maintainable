extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForVampiricCollar:
	const Receiver = preload("res://Items/Exclusive/VampiricCollar.gd")

	static func onPrepare(subject: Receiver):
		if not subject.affectedItems.is_empty():
			subject.connectForCombat(subject.character(), "character_vampirism_changed", "onVampirismChanged")
			subject.connectForCombat(subject.opponent(), "character_attacked", "onOpponentAttacked")

		subject.affectedItems_dict = Util.arrayAsIndexDict(subject.affectedItems)

	static func onOpponentAttacked(subject: Receiver, damageRes: DamageResult):
		if (damageRes.getDamage() > 0 and
			damageRes.damageSource.canApplyLifesteal() and
			damageRes.damageSource.origin in subject.affectedItems_dict):

			var lifestealFactor = subject.getP_m("lifesteal") / 100.0 * subject.character().getLucky()
			if lifestealFactor > 0:
				lifestealFactor = min(lifestealFactor, subject.maxLifesteal)
				var lifesteal = max(1, damageRes.damage * lifestealFactor)
				subject.heal(lifesteal, damageRes.event)

class ForVampiricPotion:
	const Receiver = preload("res://Items/Exclusive/VampiricPotion.gd")

	static func onPlayerDamaged(subject: Receiver, _healthChange, event):
		if subject.isEmpty(): return

		var relHealth = subject.character().getRelativeHealth()
		if relHealth < subject.healthThreshold:
			var relHealth2 = subject.opponent().getRelativeHealth()
			if relHealth2 < subject.healthThreshold:
				subject.consumePotion()
