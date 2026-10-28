extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForBadgerRune:
	const Receiver = preload("res://Items/Exclusive/BadgerRune.gd")

	static func preTakeDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.triggerOnAttacked() and subject.character().isBattleRaging():
			damageRes.applyDamageReduction(round(subject.getGemPower() * subject.damageReduction), subject)
			subject.miniActivate()

class ForBadgerSpirit:
	const Receiver = preload("res://Items/Exclusive/BadgerSpirit.gd")

	static func onDamaged(subject: Receiver, _healthChange, event):
		if not subject.activated and subject.character().getRelativeHealth() < subject.healthThreshold:
			subject.activated = true
			subject.heal(subject.character().getMaxHealth() * subject.getP_m("heal") / 100.0, event)

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getMana() >= subject.manaNeeded:
			var event = subject.useMana(subject.manaNeeded)
			subject.giveMaxHealth(subject.getP_m("maxhealth") + subject.getNumAffectedItems() *
				subject.getP_m("maxhealth_bonus"), event)
		subject.activate()

class ForBagofGiving:
	const Receiver = preload("res://Items/Exclusive/BagofGiving.gd")

	static func onShopEntered(subject: Receiver):
		var itemPool = ItemPool.new()

		for descriptor in ItemBook.items.values():
			if ItemBook.canBeGenerated(descriptor, subject.filters):
				itemPool.addItem(descriptor)
		itemPool.sortItems()

		var g = Game.getGold()
		Game.spendGold(g)

		var giftValue = ceil(g * subject.getP("value"))
		itemPool.setPrice(giftValue)

		var bagGiven = false

		while giftValue > 0:
			var giftedDescriptor
			if not bagGiven and Util.flip(0.18):
				giftedDescriptor = ItemBook.getRandomBagDescriptor()
			else:
				giftedDescriptor = itemPool.getRandomItem()

			if giftedDescriptor.isBag():
				bagGiven = true

			giftValue -= giftedDescriptor.price
			itemPool.setPrice(giftValue)

			var item = ItemBook.generateAndStorageItem(giftedDescriptor, subject.global_position)

		subject.activationParticles.global_rotation_degrees = 80
		subject.activationParticles.activate()

		Sound.playSound(subject.giveSound, - 2)
		subject.activate()
		Game.saveRunState()

	static func getRelatedItems(subject: Receiver):
		var related = []
		for classI in Game.Classes_Full.values():
			if Game.isClassUnlocked(classI) and classI != Game.Classes_Full.Adventurer:
				related.append_array(ItemBook.getShopItemsForClass(classI))
		return related

class ForBerserkerBag:
	const Receiver = preload("res://Items/Exclusive/BerserkerBag.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if not subject.activated:
			if subject.character().getRelativeHealth() < subject.healthThreshold:
				subject.activated = true
				subject.character().startBattleRage(subject, subject.getP_m("dur_rage"), event)
				subject.activate()

class ForBewitchment:
	const Receiver = preload("res://Items/Exclusive/Bewitchment.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getMana() >= subject.manaNeeded:
			var event = subject.useMana(subject.manaNeeded)

			var leastStacks = subject.getLeastStacks(subject.numDebuffs, subject.opponent(),
				Game.getDebuffs())

			if subject.rollChance(subject.getChance() * subject.typesDict[subject.Type.Nature]):
				Util.dictAdd(leastStacks, Game.EventType.Poison, subject.bonusPoison)

			if subject.rollChance(subject.getChance() * subject.typesDict[subject.Type.Dark]):
				Util.dictAdd(leastStacks, Game.EventType.Blind, subject.bonusBlind)

			if subject.rollChance(subject.getChance() * subject.typesDict[subject.Type.Ice]):
				Util.dictAdd(leastStacks, Game.EventType.Cold, subject.bonusCold)

			for debuffType in leastStacks:
				subject.giveStacks(subject.opponent(), debuffType, leastStacks[debuffType], event)

		subject.activate()

class ForBigBloodthorne:
	const Receiver = preload("res://Items/Exclusive/BigBloodthorne.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			if subject.character().getRegeneration() >= subject.regenNeeded:
				subject.useRegeneration(subject.regenNeeded)
				subject.giveVampirism(subject.vampirism)
				subject.giveSpikes(subject.spikes)
				ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)

class ForBionicArmor:
	const Receiver = preload("res://Items/Exclusive/BionicArmor.gd")

	static func onPrepare(subject: Receiver):
		subject.blockHealthAcc = 0
		var baseStaminaRegen = subject.character().baseStaminaRegen
		subject.character().giveStaminaRegeneration(subject.staminaRegenMalus * baseStaminaRegen)

		subject.connectForCombat(subject.character(), "character_healed", "onHealOrBlockChanged")
		subject.connectForCombat(subject.character(), "character_block_changed", "onHealOrBlockChanged")

	static func onHealOrBlockChanged(subject: Receiver, amount, event):
		if amount > 0:
			subject.blockHealthAcc += amount
			var numProccs = int(subject.blockHealthAcc / subject.healthThreshold)
			if numProccs > 0:
				subject.blockHealthAcc -= numProccs * subject.healthThreshold
				subject.giveMaxStaminaTemporary(subject.maxStamina * numProccs)
				subject.miniActivate()

class ForBismuthCube:
	const Receiver = preload("res://Items/Exclusive/BismuthCube.gd")

	static func onBuffsChanged(subject: Receiver, amount, event):
		var remainingUses = subject.maxUses - subject.numActivations
		if remainingUses == 0: return

		if amount > 0:
			var numProccs = 0
			subject.buffCounter += amount
			while subject.buffCounter > subject.buffsNeeded:
				numProccs += 1
				subject.buffCounter -= subject.buffsNeeded

			numProccs = min(remainingUses, numProccs)

			if numProccs > 0:
				if subject.affectedItem != null:
					if Game.cubeAdvanced.get(subject.affectedItem, subject) == subject:
						Game.cubeAdvanced[subject.affectedItem] = subject
						subject.affectedItem.advanceCooldownSeconds(subject.cdAdvance * numProccs)
					else:
						subject.affectedItem.advanceCooldownSeconds(subject.cdAdvance * numProccs * subject.penaltyFactor)

				subject.giveRandomBuffs(numProccs)
				subject.setState(subject.numActivations + numProccs)
				subject.miniActivate()

class ForBomb:
	const Receiver = preload("res://Items/Exclusive/Bomb.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.useStamina() == Character.StaminaResult.Sufficient:
			EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
			var removedBuffs = 0
			for buff in Game.getBuffs():
				var numStacks = subject.character().getStacks(buff)
				removedBuffs += numStacks
				subject.character().useStacks(buff, numStacks, subject)
			EventBus.flushLoggingQueue()

			subject.opponent().changeDamageResistance( - subject.damFactor * removedBuffs)

			var dam = subject.descriptor.minDam
			var damageRes = subject.dealEffectDamage(dam)
			subject.onAfterEffectFinished()
			subject.activationParticles.activate()
			Sound.playSound(subject.explosionSound)

class ForBookofBasics:
	const Receiver = preload("res://Items/Exclusive/BookofBasics.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getMana() >= subject.manaNeeded:
			var event = subject.useMana(subject.manaNeeded)
			subject.giveMaxHealth(subject.getP_m("maxhealth") + subject.getP_m("maxhealth_spell") * subject.bonusHealthFactor,
			event)
		subject.activate()

	static func onSaleRoll(subject: Receiver, item):
		if item != null and (item.hasType(subject.Type.Book) or item.hasType(subject.Type.Spell)):
			Game.shopSceneNode.addBonusSalesChance(subject.salesChance)

class ForBookofDarkness:
	const Receiver = preload("res://Items/Exclusive/BookofDarkness.gd")

	static func onPrepare(subject: Receiver):
		var speed = 0.0
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Dark):
				speed += subject.spellSpeed * 2
			else:
				speed += subject.spellSpeed
		subject.addSpeed(speed)

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getCurrentHealth() > subject.healthNeeded:
			var event = subject.character().loseHealth(subject.healthNeeded, subject)
			subject.giveMana(subject.mana, event)
			subject.inflictBlind(subject.blind, event)
		subject.activate()

class ForBookofIce:
	const Receiver = preload("res://Items/Exclusive/BookofIce.gd")

	static func onPrepare(subject: Receiver):
		var speed = 0.0
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Ice):
				speed += subject.spellSpeed * 2
			else:
				speed += subject.spellSpeed
		subject.addSpeed(speed)

class ForBookofLight:
	const Receiver = preload("res://Items/Exclusive/BookofLight.gd")

	static func onPrepare(subject: Receiver):
		var speed = 0.0
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Holy):
				speed += subject.spellSpeed * 2
			else:
				speed += subject.spellSpeed
		subject.addSpeed(speed)

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getMana() >= subject.manaNeeded:
			var event = subject.useMana(subject.manaNeeded)
			subject.giveRegeneration(subject.regen, event)
			subject.heal(subject.getP_m("heal"), event)
		subject.activate()

class ForBookofNature:
	const Receiver = preload("res://Items/Exclusive/BookofNature.gd")

	static func onPrepare(subject: Receiver):
		var speed = 0.0
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Nature):
				speed += subject.spellSpeed * 2
			else:
				speed += subject.spellSpeed
		subject.addSpeed(speed)

class ForBoomerang:
	const Receiver = preload("res://Items/Exclusive/Boomerang.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			subject.changeStaminaFactor( - subject.staminaReduction)
			if subject.rollChance():
				subject.stealRandomBuff(1)
				var particles = ObjectPool.particleOneShot(subject.stealParticles, subject.sprite)
				particles.position = Vector2(60, 60)

class ForBowlofTreats:
	const Receiver = preload("res://Items/Exclusive/BowlofTreats.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.giveRandomBuffs(subject.getP1())
		if subject.speedBonusGiven < subject.maxSpeedBonus:
			for item in subject.getAffectedItems():
				var curBonus = min(subject.speedBonus, subject.maxSpeedBonus - subject.speedBonusGiven)
				item.addSpeed(curBonus / 100)

			subject.speedBonusGiven += subject.speedBonus
		subject.activate()

	static func getGatedDescriptor(subject: Receiver, rarity) -> ItemDescriptor:
		var itemName: String

		if rarity >= subject.Rarity.Legendary:
			rarity = Util.pickRandomElement([Item.Rarity.Common, Item.Rarity.Rare, Item.Rarity.Epic])

		match rarity:
			subject.Rarity.Common:
				itemName = "Rat"
			subject.Rarity.Rare:
				itemName = "Squirrel"
			subject.Rarity.Epic:
				itemName = "Hedgehog"

		return ItemBook.getDescriptor(itemName)

class ForBoxofProsperity:
	const Receiver = preload("res://Items/Exclusive/BoxofProsperity.gd")

	static func onShopEntered(subject: Receiver):
		if subject.conditionFulfilled():
			var gem = ItemBook.generateItem(ItemBook.getGemOfRarity(subject.Rarity.Common))
			subject.get_parent().add_child(gem)
			gem.global_position = subject.global_position
			gem.pushToStorage(Game.STORAGEBOX.center + Util.randInBox(100, 100))
			gem.createGemParticles()
			subject.activate()
			Game.saveRunState()

class ForBrassKnuckles:
	const Receiver = preload("res://Items/Exclusive/BrassKnuckles.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			subject.addCritChancePercent(subject.getChance2())
			subject.addAccuracy(subject.extraAccuracy)
			for item in subject.getAffectedItems():
				item.addCritChancePercent(subject.getChance2())
				if item.isWeapon():
					item.addAccuracy(subject.extraAccuracy)
			if subject.rollChance():
				subject.stun(subject.getP_m("dur_stun"), damageRes.event)
				var particles = ObjectPool.particleOneShot(subject.stunParticles, subject.sprite)
				particles.position = Vector2(0, - 60)

class ForBurningBanner:
	const Receiver = preload("res://Items/Exclusive/BurningBanner.gd")

	static func onPrepare(subject: Receiver):
		for item in subject.getAffectedItems():
			subject.connectForCombat(item, "activated", "onItemActivated")

		subject.opponent().changeDebuffProtectionChance(subject.getChance2())
		subject.character().changeBuffProtectionChance(subject.getChance2())

class ForBurningSpikes:
	const Receiver = preload("res://Items/Exclusive/BurningSpikes.gd")

	static func onSpikesChanged(subject: Receiver, amount, event):
		if amount > 0 and event.origin in subject.affectedItemsDict:
			subject.spikesAcc += amount
			var numProccs = subject.spikesAcc / subject.spikesNeeded
			if numProccs > 0:
				subject.giveHeat(subject.heatForSpikes * numProccs)
				subject.spikesAcc %= subject.spikesNeeded
				subject.miniActivate()

class ForBurningSword:
	const Receiver = preload("res://Items/Exclusive/BurningSword.gd")

	static func onHeatChanged(subject: Receiver, amount, _event):
		if amount > 0:
			subject.heatCounter += amount
			var bonus = subject.heatCounter / subject.heatNeeded
			if bonus > 0:
				var bonusDamage = subject.getP3() * bonus
				for item in subject.getAffectedItems():
					item.addBonusDamage(bonusDamage)
				subject.addBonusDamage(bonusDamage)

				if Util.time >= subject.particleReadyTime:
					ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)
					subject.particleReadyTime = Util.time + 0.1

			subject.heatCounter %= subject.heatNeeded
