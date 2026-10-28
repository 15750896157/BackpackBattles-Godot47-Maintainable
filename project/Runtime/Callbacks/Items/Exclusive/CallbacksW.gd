extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForWand:
	const Receiver = preload("res://Items/Exclusive/Wand.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.giveLeastBuffs(1, subject.character(), null, subject.buffs)

		var mana = subject.character().getMana()
		var luck = subject.character().getLucky()
		var regen = subject.character().getRegeneration()

		if (mana >= subject.manaNeeded or
			luck >= subject.luckNeeded or
			regen >= subject.regenNeeded):

				var event = subject.removeMostBuffs(subject.buffsToUse, null, true, subject.buffs)
				subject.giveEmpower(subject.empower, event)

		subject.activate()

class ForWandofDissonance:
	const Receiver = preload("res://Items/Exclusive/WandofDissonance.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getCurrentHealth() > subject.healthUsed:
			var event = subject.character().loseHealth(subject.healthUsed, subject)
			var dam = subject.descriptor.minDam
			var res = subject.dealEffectDamage(dam, event)

			var maxBuffs = subject.getMostStacks(subject.character(), subject.availableBuffs.keys())
			var buffToGive = Util.pickRandomElement(maxBuffs)
			var amount = subject.availableBuffs[buffToGive]
			subject.giveStacks(subject.character(), buffToGive, amount, event)

		subject.activate()

	static func onPrepare(subject: Receiver):
		var bonusEffectDmg = 0.0
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Spell):
				bonusEffectDmg += subject.effectDmg * 2.0
			else:
				bonusEffectDmg += subject.effectDmg

		subject.character().changeEffectDamageFactor(bonusEffectDmg)

class ForWarScythe:
	const Receiver = preload("res://Items/Exclusive/WarScythe.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			if subject.opponent().getPoison() >= subject.poisonNeeded:
				subject.opponent().losePoison(subject.poisonNeeded, subject)
				subject.addCritChancePercent(subject.getChance())
				subject.addCritSeverity(subject.critDamage)

class ForWingedBoots:
	const Receiver = preload("res://Items/Exclusive/WingedBoots.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if subject.hasActivated: return

		var relHealth = subject.character().getRelativeHealth()
		if relHealth < subject.healthThreshold:
			subject.hasActivated = true
			subject.giveEmpower(subject.empower, event)
			subject.cleanseRandomDebuffs(subject.debuffs)
			subject.character().changeDodgeStacks(subject.dodges)
			subject.consume()

class ForWisp:
	const Receiver = preload("res://Items/Exclusive/Wisp.gd")

	static func onAttack(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			subject.damageAcc += damageRes.damage
			var numProccs = subject.damageAcc / subject.damageForSpikes
			if numProccs > 0:
				subject.damageAcc %= subject.damageForSpikes
				subject.giveSpikes(subject.spikes * numProccs)
				subject.miniActivate()

	static func doCooldownEffect(subject: Receiver):
		match subject.getGemMode():
			subject.GemMode.Inventory:
				subject.giveLucky(subject.luck)
				subject.giveRegeneration(subject.regen)
				subject.onAfterEffectFinished()

			subject.GemMode.Armor:
				var bonusHealth = subject.getP_m("maxhealth") / 100.0 * subject.character().getCurrentHealth()
				bonusHealth *= subject.getGemPower()
				subject.giveMaxHealth(bonusHealth)
				subject.onAfterEffectFinished(false)
				subject.consumed = true
				subject.miniActivate()

class ForWolfBadge:
	const Receiver = preload("res://Items/Exclusive/WolfBadge.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if not subject.activated:
			if subject.character().getRelativeHealth() < subject.healthThreshold:
				subject.activated = true
				subject.character().startBattleRage(subject, subject.getP_m("dur"), event)
				subject.activate()

class ForWolfEmblem:
	const Receiver = preload("res://Items/Exclusive/WolfEmblem.gd")

	static func onPrepare(subject: Receiver):
		var bonusCritChance = subject.getChance()
		bonusCritChance += subject.getAffectedItems(subject.Affected.Secondary).size() * subject.getChance2()

		for item in subject.getAffectedItems():
			item.changeCritChancePercent(bonusCritChance)

class ForWrench:
	const Receiver = preload("res://Items/Exclusive/Wrench.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var item1 = subject.getFirstAffectedItem(subject.Affected.Primary)
			if item1 != null:
				item1.changeAmplificiationChancePercent_allBuffs(subject.getChance())

			var item2 = subject.getFirstAffectedItem(subject.Affected.Secondary)
			if item2 != null:
				item2.changeCritChancePercent(subject.getChance2())
