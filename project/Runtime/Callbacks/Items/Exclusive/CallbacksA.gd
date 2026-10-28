extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForAcornAce:
	const Receiver = preload("res://Items/Exclusive/AcornAce.gd")

	static func onAddToInventory_deferred(subject: Receiver):
		if subject.isOwnedByOpponent():
			for descr in subject.collarDescriptors:
				for collar in subject.getAllInInventoryOfType(descr):
					collar.activateExtendedAffectedCells()

		elif subject.ownerType == subject.Owner.PlayerInventory:
			for descr in subject.collarDescriptors:
				for collar in ItemBook.getItemsOnScreenOfType(descr):
					collar.activateExtendedAffectedCells()

class ForAmuletofAgility:
	const Receiver = preload("res://Items/Exclusive/AmuletofAgility.gd")

	static func onBuffChanged(subject: Receiver, amount, event):
		if amount < 0 and event.getParam("used", false):
			var used = - amount
			var buffType = event.getType()
			subject.usedStacks[buffType] += used * subject.refund
			var toRefund = int(round(subject.usedStacks[buffType]))

			if toRefund > 0:
				subject.usedStacks[buffType] -= toRefund
				subject.giveStacks(subject.character(), buffType, toRefund, event)
				subject.miniActivate()

class ForAmuletofAlchemy:
	const Receiver = preload("res://Items/Exclusive/AmuletofAlchemy.gd")

	static func onPotionEmptied(subject: Receiver, potion):
		if subject.rollChance():
			subject.potionsToTrigger.push_back(potion)
			subject.potionTriggerTimer.start(subject.delay)
			var ani = ObjectPool.instantiate(subject.triggerAnimation)
			subject.get_parent().add_child(ani)
			ani.global_position = subject.global_position
			ani.moveTo(potion.global_position, subject.delay)

class ForAmuletofDarkness:
	const Receiver = preload("res://Items/Exclusive/AmuletofDarkness.gd")

	static func onItemActivated(subject: Receiver, event):
		if subject.rollChance():
			var dam = subject.descriptor.minDam
			var res = subject.dealEffectDamage(dam)
			subject.activate()
			var particles = ObjectPool.particleOneShot(subject.activationParticles, subject)
			subject.move_child(particles, 0)

	static func onOpponentDamaged(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit() and damageRes.damageSource.isEffectDamage():
			subject.damageAcc += damageRes.damage

			var proccs = subject.damageAcc / subject.damageThreshold
			if proccs > 0:
				subject.damageAcc %= subject.damageThreshold
				subject.inflictRandomDebuffs(proccs)
				subject.miniActivate()

class ForAmuletofLight:
	const Receiver = preload("res://Items/Exclusive/AmuletofLight.gd")

	static func onItemActivated(subject: Receiver, event):
		if event.origin.hasType(subject.Type.Holy):
			if subject.rollChance2():
				subject.giveRegeneration(subject.regenOnActivate, event)
				subject.miniActivate()
		else:
			if subject.rollChance():
				subject.giveRegeneration(subject.regenOnActivate, event)
				subject.miniActivate()

class ForAmuletUnidentified:
	const Receiver = preload("res://Items/Exclusive/AmuletUnidentified.gd")

	static func identifyAmulet(subject: Receiver, dropResult):

		var amulet = ItemBook.generateItem(Util.pickRandomElement(ItemBook.amulets))
		if subject.wasAddedToInventory(dropResult):
			subject.inventory.replaceItem(subject, amulet)
		else:
			Game.STORAGEBOX.removeItem(subject)
			subject.collisionShape.disabled = true
			subject.discard()
			Game.playerNode.add_child(amulet)

			amulet.global_position = subject.global_position
			amulet.addToStorageBox(true, true, true, subject.global_position)

		Sound.playSound(subject.revealSound, 6)
		var pulse = ObjectPool.instantiate(subject.revealPulseScene)
		pulse.self_modulate = amulet.amuletColor
		Game.playerNode.add_child(pulse)
		pulse.global_position = subject.global_position
		pulse.get_node("AnimationPlayer").play("Activate")
		Game.saveRunState()
		subject.finishReplacement()

class ForAnvil:
	const Receiver = preload("res://Items/Exclusive/Anvil.gd")

	static func onPreCombatStart(subject: Receiver):
		var numCrafted = subject.getAffectedItems().size()
		if numCrafted > 0:
			var bonusDamage = subject.getP1() * numCrafted
			var staminaReduction = - subject.getP2() * numCrafted
			for affectedWeapon in subject.getAffectedItems(subject.Affected.Secondary):
				if affectedWeapon.canBeEmpowered():
					affectedWeapon.addBonusDamage(bonusDamage)
					var event = Game.combatLog.createEvent_DamageBuff(subject, affectedWeapon, bonusDamage, subject.character().playerId)
					EventBus.logEvent(event)

				affectedWeapon.changeStaminaFactor(staminaReduction)
		subject.activate()

class ForArcaneBoots:
	const Receiver = preload("res://Items/Exclusive/ArcaneBoots.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if subject.hasActivated: return

		var relHealth = subject.character().getRelativeHealth()
		if relHealth < subject.healthThreshold:
			if subject.character().getMana() >= subject.manaNeeded:
				subject.hasActivated = true
				var event2 = subject.useMana(subject.manaNeeded)
				subject.giveLucky(subject.luck, event2)
				subject.giveEmpower(subject.empower, event2)
				subject.giveBlock(subject.getBlock(), true, event2)

				for item in subject.getAffectedItems():
					item.addSpeed(subject.bonusSpeed)

				subject.speedTimer.start(subject.getP_m("dur_speed"))

				subject.consume()

class ForArmoredPowerPuppy:
	const Receiver = preload("res://Items/Exclusive/ArmoredPowerPuppy.gd")

	static func onPrepare(subject: Receiver):
		var numFood = 0
		var numPets = 0
		for item in subject.getAffectedItems():
			if item.hasType(subject.Type.Food):
				numFood += 1
			elif item.hasType(subject.Type.Pet):
				numPets += 1

		subject.addSpeed((numPets * subject.getP4() + numFood * subject.getP5()) / 100.0)
		subject.options = [0, 1, 2]

class ForArtifactStoneDeath:
	const Receiver = preload("res://Items/Exclusive/ArtifactStoneDeath.gd")

	static func onFatigueDamageChanged(subject: Receiver):
		var fatigueDam = Game.fatigueDamageSource.minDamage + subject.opponent().getBonusFatigueDamage()
		var fatigueDiff = fatigueDam - subject.lastFatigueDam
		subject.lastFatigueDam = fatigueDam

		for item in subject.getAffectedItems():
			item.changeCritChancePercent(subject.getChance() * fatigueDiff)
