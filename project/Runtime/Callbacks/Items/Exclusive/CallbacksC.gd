extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCauldron:
	const Receiver = preload("res://Items/Exclusive/Cauldron.gd")

	static func doCooldownEffect(subject: Receiver):
		var rng = Util.pickRandomElement(subject.options)
		var particles = ObjectPool.particleOneShot(subject.activationParticlesScene, subject.sprite)
		if rng == 0:
			subject.heal()
			particles.self_modulate = subject.healColor
		elif rng == 1:
			subject.giveMana(subject.getP2())
			particles.self_modulate = subject.manaColor
		else:
			subject.giveHeat(subject.getP3())
			particles.self_modulate = subject.heatColor
		subject.activate()

		subject.options = [0, 1, 2]
		subject.options.erase(rng)

class ForChainWhip:
	const Receiver = preload("res://Items/Exclusive/ChainWhip.gd")

	static func onOpponentBuffsChanged(subject: Receiver, amount, event):
		if amount < 0:
			if event.getOrigin() is Item and event.getOrigin().character() == subject.character():
				subject.buffsPurged += - amount
				subject.addBonusDamage( - amount * subject.getP3())

class ForChargeSplitter:
	const Receiver = preload("res://Items/Exclusive/ChargeSplitter.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getHeat() >= subject.heatNeeded:
			var event = subject.useHeat(subject.heatNeeded)
			subject.giveLucky(subject.luck, event)
			subject.giveBlock(subject.getBlock(), true, event)

		subject.onAfterEffectFinished()

	static func emitCharge(subject: Receiver, speedFactor):
		var event = subject.activate()
		subject.sendCharge(subject.getP_m("dur"), subject.chargeCells1, speedFactor, event)
		subject.sendCharge(subject.getP_m("dur"), subject.chargeCells2, speedFactor, event)

class ForChessMaster:
	const Receiver = preload("res://Items/Exclusive/ChessMaster.gd")

	static func onShopEntered(subject: Receiver):
		var chessboards = subject.getAllInInventoryOfType(ItemBook.chessboardDescriptor)
		if not chessboards.is_empty():
			var weights = [0, 0, 0, 0, 0, 0]
			var roundsPassed = Game.curRound - Game.SKILL_ROUND1
			weights[0] = 2
			weights[1] = (roundsPassed - subject.firstKnightRound) * 2 if roundsPassed > subject.firstKnightRound else 0
			weights[2] = weights[1]
			weights[3] = (roundsPassed - subject.firstRookRound) * 2 if roundsPassed > subject.firstRookRound else 0
			weights[4] = 5 if roundsPassed >= subject.firstQueenRound else 0
			weights[5] = weights[3]

			var bag = WeightedBag.new()
			var index = bag.rollOnce(weights)
			var pieceDescriptor
			if Util.roll():
				pieceDescriptor = chessboards[0].blackPieces[index]
			else:
				pieceDescriptor = chessboards[0].whitePieces[index]
			var piece = ItemBook.generateItem(pieceDescriptor)
			var adjacentCells = subject.inventory.getAdjacentCells(subject.occupiedCells)
			subject.placeGeneratedItem(piece, adjacentCells)
			subject.activate(null, false)
			Game.saveRunState()

class ForChromeCube:
	const Receiver = preload("res://Items/Exclusive/ChromeCube.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if subject.hasActivated: return

		var relHealth = subject.opponent().getRelativeHealth()
		if relHealth < subject.healthThreshold:
			subject.hasActivated = true

			if subject.affectedItem != null:
				subject.advanceAffectedItem()

			subject.opponent().reduceHealingEfficiency(subject.healReduction)
			subject.consume()

class ForCog:
	const Receiver = preload("res://Items/Exclusive/Cog.gd")

	static func onSold(subject: Receiver):
		var ani = subject.cogWheelAnimation.instantiate()
		Game.playerNode.add_child(ani)
		ani.get_node("AnimationPlayer").play("Turn")
		Sound.playSound(subject.craftingSound, 4)
		Game.fuseAll()

class ForCriticalPoison:
	const Receiver = preload("res://Items/Exclusive/CriticalPoison.gd")

	static func onWeaponAttacked(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			subject.damageAcc += damageRes.damage

			var poisonStacks = subject.damageAcc / subject.damagePerPoison
			if poisonStacks > 0:
				subject.inflictPoison(poisonStacks * subject.poison, damageRes.event)
				subject.damageAcc %= subject.damagePerPoison
				subject.miniActivate()

class ForCrow:
	const Receiver = preload("res://Items/Exclusive/Crow.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.numActivations < subject.maxActivations:
			for item in subject.getAffectedItems():

				item.addSpeed(subject.speedBonus)
				item.changeAmplificiationChancePercent_allDebuffs(subject.getChance())

			subject.numActivations += 1
			ObjectPool.particleOneShot(subject.activationParticles, subject)

		var luckToRemove = min(subject.luck, subject.opponent().getLucky())
		if luckToRemove > 0:
			subject.stealStack(Game.EventType.Lucky, luckToRemove)

		subject.activate()

class ForCthulhu:
	const Receiver = preload("res://Items/Exclusive/Cthulhu.gd")

	static func onPrepare(subject: Receiver):
		subject.affectedFood.clear()
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Food):
				subject.affectedFood.push_back(item)

		subject.addSpeed(subject.foodSpeed * subject.getNumAffectedItems())

class ForCubert:
	const Receiver = preload("res://Items/Exclusive/Cubert.gd")

	static func onItemActivated2(subject: Receiver, event):
		if subject.character().getRegeneration() >= subject.regenNeeded:
			if subject.rollChance2():
				var event2 = subject.useRegeneration(subject.regenNeeded, event)
				subject.giveEmpower(subject.empower, event2)
				subject.miniActivate()

class ForCupcakeDragon:
	const Receiver = preload("res://Items/Exclusive/CupcakeDragon.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var buffsLeft = subject.buffRemoval
			var ownMostBuffs = subject.getMostStacks(subject.character(), Game.getBuffs())
			ownMostBuffs.shuffle()
			for buffType in ownMostBuffs:
				var cur = subject.opponent().getStacks(buffType)
				var buffsRemoved = min(cur, buffsLeft)
				subject.opponent().loseStacks(buffType, buffsRemoved, subject)
				buffsLeft -= buffsRemoved
				if buffsLeft == 0:
					break

			var oppoMostBuffs = subject.getMostStacks(subject.opponent(), Game.getBuffs())
			subject.giveStacks(subject.character(), Util.pickRandomElement(oppoMostBuffs),
				subject.buffGain)
