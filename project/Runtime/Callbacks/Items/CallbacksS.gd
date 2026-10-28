extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForSpectralDagger:
	const Receiver = preload("res://Items/SpectralDagger.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var event = subject.tryUseMana(subject.getP1())
			if event:
				damageRes.damage += subject.getP2()
				damageRes.damageSource.makeSpectral()
				var particles = ObjectPool.particleOneShot(subject.activationParticleScene, subject.sprite)
				particles.position = Vector2(30, - 20)

class ForStaffofUnhealing:
	const Receiver = preload("res://Items/StaffofUnhealing.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.useStamina() == Character.StaminaResult.Sufficient:
			var healAmount = subject.getP_m("heal")
			if subject.character().getMana() >= subject.manaCost:
				if not subject.buffActive:
					subject.setState(true, true)
					subject.character().giveUnhealing(1.0)
				subject.unhealingTimer.start(subject.getP_m("dur_unhealing"))
				var event = subject.useMana(subject.manaCost)
				Util.createPulse(subject.activationPulse, subject, subject.get_node("Icon/PulsePosition").global_position)
				subject.heal(healAmount, event)
			else:
				subject.heal(healAmount)

			subject.activate()

class ForStone:
	const Receiver = preload("res://Items/Stone.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.ammunition >= 1 and subject.useStamina() == Character.StaminaResult.Sufficient:
			subject.ammunition -= 1

			var res = subject.dealDamage()

			if subject.ammunition == 0:
				subject.onAfterEffectFinished(false)
				subject.consume(res)
			else:
				subject.activate(res)

class ForStrongDemonicFlask:
	const Receiver = preload("res://Items/StrongDemonicFlask.gd")

	static func onTriggerPotion(subject: Receiver, triggerEvent):
		subject.opponent().reduceHealingEfficiency(subject.healingDebuff)
		var dam = subject.opponent().getDebuffStacks() * subject.damPerDebuff
		dam = ceil(dam)
		subject.stealLife(dam, subject.getP_m("lifesteal") / 100.0, triggerEvent)
		subject.healingReductionTimer.start(subject.getP_m("dur"))

	static func drinkStrongDemonicFlask(subject: Receiver, event):

		subject.drink()

		subject.triggerPotion(event)

		var affected = subject.getAffectedItems()
		if not affected.is_empty():
			affected[0].triggerPotion(event)
			affected[0].miniActivate()

		subject.activate()
