extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForHalberd:
	const Receiver = preload("res://Items/Exclusive/Halberd.gd")

	static func onPreDealDamage_late(subject: Receiver, damageRes: DamageResult):

		var curBlock = subject.opponent().getBlock()
		var toRemove = min(curBlock, subject.totalBlockRemoval)
		subject.removeBlock(toRemove, damageRes.event)
		var toGive = subject.totalBlockRemoval - toRemove
		if toGive > 0:
			subject.giveBlock(toGive, true, damageRes.event)

class ForHardwood:
	const Receiver = preload("res://Items/Exclusive/Hardwood.gd")

	static func onItemsCounted(subject: Receiver):
		subject.hasCommonMeleeWeapon = false
		for item in ItemBook.getOwnedItems():
			if (item.descriptor.isMeleeWeapon() and
				item.getRarity() == subject.Rarity.Common):
				subject.hasCommonMeleeWeapon = true
				return

class ForHeartShield:
	const Receiver = preload("res://Items/Exclusive/HeartShield.gd")

	static func onPrepare(subject: Receiver):
		for item in subject.getAffectedItems():
			item.giveBuffPower(Game.EventType.Block, subject.blockFactor)
			item.changeHealAmp(subject.healamp)
			item.changeAmplificiationChancePercent(Game.EventType.Regeneration, subject.getChance2())

		subject.setState(false)
		subject.connectForCombat(subject.character(), "character_regeneration_changed", "onRegenChanged")
		subject.regenGiven = 0

	static func onRegenChanged(subject: Receiver, amount, event):
		if amount > 0 and not subject.activated and subject.character().getRegeneration() >= subject.regenNeeded:
			subject.setState(true, true)
			var event2 = subject.useRegeneration(subject.regenNeeded, event)
			subject.giveMaxHealth(subject.getP_m("maxhealth"), event2)

class ForHeavyDrinking:
	const Receiver = preload("res://Items/Exclusive/HeavyDrinking.gd")

	static func onPrepare(subject: Receiver):
		subject.addSpeed(subject.getNumDistinctAffectedItems() * subject.potionSpeed)

		subject.allPotions.clear()
		for item in subject.inventory.getItems():
			if item.hasType(subject.Type.Potion) and item != subject:
				subject.allPotions.push_back(item)

	static func doCooldownEffect(subject: Receiver):
		if not subject.allPotions.is_empty():
			var potionToTrigger = Util.pickRandomElement(subject.allPotions)
			potionToTrigger.triggerPotion()
			potionToTrigger.miniActivate()
			var particles = ObjectPool.particleOneShot(subject.activationParticles, subject.get_parent())
			particles.global_position = potionToTrigger.global_position

		subject.activate()

class ForHolyCollar:
	const Receiver = preload("res://Items/Exclusive/HolyCollar.gd")

	static func onPrepare(subject: Receiver):
		for item in subject.affectedItems:
			subject.connectForCombat(item, "activated", "onItemActivated")

		if not subject.affectedItems.is_empty():
			subject.connectForCombat(subject.character(), "character_lucky_changed", "onLuckyOrRegenChanged")
			subject.connectForCombat(subject.character(), "character_regeneration_changed", "onLuckyOrRegenChanged")

class ForHyperHedgehog:
	const Receiver = preload("res://Items/Exclusive/HyperHedgehog.gd")

	static func doCooldownEffect(subject: Receiver):
		var dam = subject.descriptor.minDam
		dam += subject.character().getSpikes() * subject.damagePerSpike
		dam += subject.character().getEmpower() * subject.damagePerEmpower
		var res = subject.dealEffectDamage(dam)
		subject.activate(res)
