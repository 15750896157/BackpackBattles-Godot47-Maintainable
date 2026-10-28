extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForParadiseBirb:
	const Receiver = preload("res://Items/Exclusive/ParadiseBirb.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.numActivations < subject.maxActivations:

			for item in subject.getAffectedItems():
				item.addSpeed(subject.speedBonus)
				item.changeAmplificiationChancePercent_allBuffs(subject.getChance())
				item.changeHealAmp(subject.bonusHeal)

			subject.numActivations += 1
			ObjectPool.particleOneShot(subject.activationParticles, subject)

			if subject.numActivations == subject.maxActivations:
				subject.onAfterEffectFinished()
			else:
				subject.activate()

class ForPhoenix:
	const Receiver = preload("res://Items/Exclusive/Phoenix.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if subject.deathPrevented:
			return

		if subject.character().getCurrentHealth() <= 0:
			var heat = subject.character().getHeat()
			if heat > 0:
				subject.setState(true)

				var event2 = subject.character().reincarnate(subject.reincarnateHealth * heat, false, subject, event)
				subject.useHeat(heat, event2)
				subject.activate()
				Util.createPulse(subject.resurrectionPulse, subject, subject.global_position)

	static func doCooldownEffect(subject: Receiver):
		if subject.useStamina() == Character.StaminaResult.Sufficient:
			if subject.character().getCurrentHealth() > subject.selfDam:
				subject.character().loseHealth(subject.selfDam, subject)
				var res: DamageResult = subject.dealDamage()
				subject.activate(res)

class ForPlasticCube:
	const Receiver = preload("res://Items/Exclusive/PlasticCube.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.deactivateCooldown()

		var affectedItem = subject.getFirstAffectedItem()
		if affectedItem != null:
			if not affectedItem in Game.cubeAdvanced:
				Game.cubeAdvanced[affectedItem] = subject
				affectedItem.advanceCooldownPercent(subject.cdAdvance)
			else:
				affectedItem.advanceCooldownPercent(subject.cdAdvance * subject.penaltyFactor)

		subject.giveSpikes(subject.spikes)
		subject.onAfterEffectFinished()

class ForPoisonFrog:
	const Receiver = preload("res://Items/Exclusive/PoisonFrog.gd")

	static func onBuffsChanged(subject: Receiver, amount, event):
		if event.getOrigin() in subject.affectedItemsDict:
			if amount > 0:
				subject.gainedBuffs += amount
				var ticks = subject.gainedBuffs / subject.gainedThreshold
				if ticks > 0:
					subject.heal()

					subject.gainedBuffs %= subject.gainedThreshold
					subject.miniActivate()

			else:

				subject.usedBuffs += int(abs(amount))
				var ticks = subject.usedBuffs / subject.usedThreshold
				if ticks > 0:
					subject.inflictPoison(ticks * subject.poison, event)
					subject.giveMana(ticks * subject.mana, event)
					subject.usedBuffs %= subject.usedThreshold
					subject.miniActivate()

class ForPoisonGrenade:
	const Receiver = preload("res://Items/Exclusive/PoisonGrenade.gd")

	static func onLuckChanged(subject: Receiver, amount, event):
		if amount > 0 and not subject.poisonCritActive and subject.character().getLucky() >= subject.luckNeeded:
			subject.opponent().changePoisonCritChancePercent(subject.getChance())
			subject.setState(true)

		elif amount < 0 and subject.poisonCritActive and subject.character().getLucky() < subject.luckNeeded:
			subject.opponent().changePoisonCritChancePercent( - subject.getChance())
			subject.setState(false)

	static func onStateChanged(subject: Receiver, _poisonCritActive):
		subject.poisonCritActive = _poisonCritActive
		subject.tween = Util.refreshTween(subject.tween)
		if subject.poisonCritActive:
			subject.tween.tween_property(subject.light, "self_modulate:a", 0.15, 0.1)

		else:
			subject.tween.tween_property(subject.light, "self_modulate:a", 0.0, 0.2)

class ForPoisonShortbow:
	const Receiver = preload("res://Items/Exclusive/PoisonShortbow.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit() and subject.rollChance():
			var randomDebuff = Util.pickRandomElement(Game.getDebuffs())
			if randomDebuff == Game.EventType.Poison:
				subject.inflictPoison(subject.poison + 1)
			else:
				subject.inflictPoison(subject.poison)
				subject.giveStacks(subject.opponent(), randomDebuff, 1)
			ObjectPool.particleOneShot(subject.poisonParticlesScene, subject)

class ForPop:
	const Receiver = preload("res://Items/Exclusive/Pop.gd")

	static func onManaChanged(subject: Receiver, _amount, _event):
		var speed = min(subject.maxSpeedBonus, subject.speedPerMana * subject.character().getMana())
		if speed - subject.previousSpeedBonus != 0:
			subject.addSpeed(speed - subject.previousSpeedBonus)
			subject.previousSpeedBonus = speed

class ForPortableAltar:
	const Receiver = preload("res://Items/Exclusive/PortableAltar.gd")

	static func onRecipesUpdated(subject: Receiver):
		if subject.ownerType != subject.Owner.PlayerInventory: return
		if subject.fusing: return

		if subject.locked or not subject.placed:
			for bonded in subject.bondedIngredients:
				bonded.removeBondedBaseItem()
			subject.removeAllIngredients()
			return

		for item in subject.getItemsInside():
			if item.canStartNewRecipe():
				subject.bondedIngredients.push_back(item)
				subject.createBondVisual(item)
				subject.updateBondVisuals()
				item.addToBaseItem(subject)

class ForPot:
	const Receiver = preload("res://Items/Exclusive/Pot.gd")

	static func onPrepare(subject: Receiver):
		subject.numFood = subject.getNumAffectedItems(subject.Affected.Secondary)
		subject.addSpeed(subject.foodPotionSpeed * (subject.getNumAffectedItems() + subject.numFood))

		for item in subject.getAffectedItems():
			subject.connectForCombat(item, "potion_triggered", "onPotionTriggered")

class ForPoweroftheMoon:
	const Receiver = preload("res://Items/Exclusive/PoweroftheMoon.gd")

	static func onPrepare(subject: Receiver):
		subject.connectForCombat(Game.combatTimer, "fatigue_start", "onFatigueStarted")

		for item in subject.getAffectedItems():
			if item.isA(subject.moonArmorDescriptor):

				subject.connectForCombat(item, "activated", "onMoonArmorActivated")
			else:

				subject.connectForCombat(item, "activated", "onMoonShiedActivated")

class ForPowerPuppy:
	const Receiver = preload("res://Items/Exclusive/PowerPuppy.gd")

	static func doCooldownEffect(subject: Receiver):
		var rng = Util.pickRandomElement(subject.options)
		if rng == 0:
			subject.giveLucky(subject.getP1())
		elif rng == 1:
			subject.giveRegeneration(subject.getP2())
		else:
			subject.giveEmpower(subject.getP3())
		subject.activate()

		subject.options = [0, 1, 2]
		subject.options.erase(rng)

class ForPrismaticWand:
	const Receiver = preload("res://Items/Exclusive/PrismaticWand.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.giveAllBuffs()

		var mana = subject.character().getMana()
		var luck = subject.character().getLucky()
		var regen = subject.character().getRegeneration()

		if (mana >= subject.manaNeeded or
			luck >= subject.luckNeeded or
			regen >= subject.regenNeeded):

				var event = subject.removeMostBuffs(subject.buffsToUse, null, true, subject.buffs)
				subject.giveEmpower(subject.empower, event)

		subject.activate()
