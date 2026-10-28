extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForThornbloom:
	const Receiver = preload("res://Items/Exclusive/Thornbloom.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			subject.giveSpikes(subject.spikes)

			var particles = ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)
			if subject.rollChance():
				subject.giveEmpower(subject.empower)
				particles.modulate = Color(0.6, 1.1, 0.2)
			else:
				particles.modulate = Color(0.4, 1.4, 0.2)

class ForThorsHammer:
	const Receiver = preload("res://Items/Exclusive/ThorsHammer.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			if subject.rollChance():
				subject.stun(subject.getP_m("dur_stun"), damageRes.event)
				var particles = ObjectPool.particleOneShot(subject.stunParticles, subject.sprite)
				particles.position = Vector2(175, - 144)

			if subject.character().getMana() >= subject.manaNeeded:
				var event = subject.useMana(subject.manaNeeded, damageRes.event)
				subject.dealEffectDamage(subject.effectDmg, event, subject.effectDmgSource)
				var duration = subject.getP_m("dur_blind")
				subject.giveStacksTemporary(subject.opponent(), Game.EventType.Blind,
					subject.blind, duration, event)

class ForTigerRune:
	const Receiver = preload("res://Items/Exclusive/TigerRune.gd")

	static func onBuffsChanged(subject: Receiver, amount, event):
		if amount > 0:
			subject.buffCounter += amount
			var relBuffs = subject.buffCounter / subject.buffsNeeded
			var block = relBuffs * subject.blockForBuffs
			subject.buffCounter %= subject.buffsNeeded
			if block > 0:
				subject.giveBlock(subject.getGemPower() * block, event)
				subject.showCooldownSmooth(relBuffs, true)
			else:
				subject.showCooldownSmooth(relBuffs, false)

class ForTimeDilator:
	const Receiver = preload("res://Items/Exclusive/TimeDilator.gd")

	static func onPrepare(subject: Receiver):
		subject.tickI = 0
		var allItems = Game.PLAYER.INVENTORY.getItems() + Game.OPPONENT.INVENTORY.getItems()
		for item in allItems:
			if item.isWeapon():
				item.reduceSpeed(subject.slow)

	static func doCooldownEffect(subject: Receiver):
		var slowestCd = 0.0
		var slowestItem = null

		for item in subject.inventory.getItems():
			if item.hasCooldown() and item.isCooldownActive():
				var cd = item.getModifiedCooldown()
				if cd > slowestCd:
					slowestCd = cd
					slowestItem = item

		slowestItem.addSpeed(subject.speedUp)
		subject.activate()
		var ani = ObjectPool.instantiate(subject.timeDilatorAni)
		subject.get_parent().add_child(ani)
		ani.global_position = slowestItem.global_position
		ani.z_index = subject.z_index + 2
		subject.tickI += 1

class ForToad:
	const Receiver = preload("res://Items/Exclusive/Toad.gd")

	static func onBuffsChanged(subject: Receiver, amount, event):
		if event.getOrigin() in subject.affectedItemsDict:
			if amount > 0:
				subject.gainedBuffs += amount
				var ticks = subject.gainedBuffs / subject.gainedThreshold
				if ticks > 0:
					subject.onGainThresholdReached(ticks, event)
					subject.gainedBuffs %= subject.gainedThreshold
			else:

				subject.usedBuffs += int(abs(amount))
				var ticks = subject.usedBuffs / subject.usedThreshold
				if ticks > 0:
					subject.onUseThresholdReached(ticks, event)
					subject.usedBuffs %= subject.usedThreshold

class ForToolbox:
	const Receiver = preload("res://Items/Exclusive/Toolbox.gd")

	static func onOpponentDamaged(subject: Receiver, damageRes: DamageResult):
		if subject.character().isBattleRaging():
			if damageRes.hasHit() and damageRes.damageSource.canApplyLifesteal():
				subject.heal(ceil(subject.getP_m("lifesteal") / 100.0 * damageRes.damage), damageRes.event)

class ForTwine:
	const Receiver = preload("res://Items/Exclusive/Twine.gd")

	static func onTriggerItemActivated(subject: Receiver, event):
		var totalChance = subject.getBaseChance()
		totalChance += subject.getNumAffectedItems(subject.Affected.Secondary) * subject.getBaseChance2()
		if subject.rollChance(totalChance):
			subject.giveMaxHealth(subject.maxHealth, event)
			subject.activate()
