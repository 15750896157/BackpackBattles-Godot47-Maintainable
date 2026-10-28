extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForBloodthorne:
	const Receiver = preload("res://Items/Bloodthorne.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var numRegen = subject.character().getRegeneration()
			if numRegen >= subject.regenNeeded:
				var event = subject.useRegeneration(subject.regenNeeded)
				subject.giveVampirism(subject.vampirism, event)
				subject.giveSpikes(subject.spikes, event)
				ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)

class ForBloodyDagger:
	const Receiver = preload("res://Items/BloodyDagger.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			if subject.vampirismStacks < subject.getP2():
				subject.giveVampirism(subject.getP1())
				subject.vampirismStacks += subject.getP1()
				ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)

			var numAffected = subject.getNumAffectedItems()
			if numAffected > 0:
				subject.heal(numAffected * subject.getP_m("heal"))

class ForBowandArrow:
	const Receiver = preload("res://Items/BowandArrow.gd")

	static func onWeaponAttacked(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var dmgAdded = false
			var attackEffectCount = 1 + subject.rollDoubleAttackEffect()
			for i in attackEffectCount:
				if subject.bonusDmg < subject.maxDmg:
					subject.bonusDmg += subject.bonusDmgPerHit
					subject.addBonusDamage(subject.bonusDmgPerHit)
					dmgAdded = true

			if dmgAdded:
				subject.setState(subject.bonusDmg, false, damageRes.event)

	static func onStateChanged(subject: Receiver, _bonusDmg):
		if _bonusDmg > 0:
			subject.activationParticles.activate()
			subject.activationParticles.scale = Vector2.ONE * min(3, 1.5 + 0.1 * _bonusDmg)
			subject.light.show()
			subject.light.scale = subject.activationParticles.scale * 0.15
		else:
			subject.activationParticles.deactivate()
			subject.light.hide()

class ForBoxofRiches:
	const Receiver = preload("res://Items/BoxofRiches.gd")

	static func onShopEntered(subject: Receiver):
		for i in subject.numGems:
			var gem = ItemBook.generateItem(ItemBook.getGemOfRarity(subject.Rarity.Common))

			var adjacentCells = subject.inventory.getAdjacentCells(subject.occupiedCells)
			subject.placeGeneratedItem(gem, adjacentCells)

			gem.createGemParticles()

		subject.activate(null, false)
		Game.saveRunState()

	static func getGatedDescriptor(subject: Receiver, rarityOdds, numHighRolls) -> ItemDescriptor:
		var rarity = 0
		if Util.rng.randf() < 0.25:

			rarity = ItemBook.getRandomRarity(rarityOdds)
		else:

			var maxRarity = Item.Rarity.Common - 1
			for r in rarityOdds:
				if r > 0:
					maxRarity += 1
			rarity = min(maxRarity, ItemBook.getRandomRarity(subject.gemOdds))

		rarity += numHighRolls
		rarity = min(rarity, Item.Rarity.Godly)

		return ItemBook.getGemOfRarity(rarity)

class ForBroom:
	const Receiver = preload("res://Items/Broom.gd")

	static func onDealtDamage(subject: Receiver, damageRes):
		if damageRes.hasHit():
			if subject.rollChance():
				subject.inflictBlind(1, damageRes.event)
				var particles = ObjectPool.particleOneShot(subject.blindParticles, subject.sprite)
				particles.position = Vector2(0, 230)
				particles.global_rotation = 0

class ForBurningTorch:
	const Receiver = preload("res://Items/BurningTorch.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit() and subject.rollChance():
			subject.addBonusDamage(subject.permDamBonus)
			var particles = ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)
			particles.scale = Vector2(1.2, 1.2)
