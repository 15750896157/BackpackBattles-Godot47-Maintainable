extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForSapphireWhelp:
	const Receiver = preload("res://Items/Exclusive/SapphireWhelp.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var event = subject.tryUseMana(subject.getP2())
			if event:
				subject.giveBlock(subject.getBlock(), true, event)
				subject.giveRandomBuffs(1, event, subject.stackTypes)

class ForScholarBag:
	const Receiver = preload("res://Items/Exclusive/ScholarBag.gd")

	static func onPrepare(subject: Receiver):
		for item in subject.getAffectedItemsInside():
			item.changeAmplificiationChancePercent(Game.EventType.Mana, subject.getChance())

		subject.character().changeProtectionChance(Game.EventType.Mana, subject.getChance2())

class ForScissorswords:
	const Receiver = preload("res://Items/Exclusive/Scissorswords.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			if subject.character().getLucky() >= subject.luckNeeded:
				var event = subject.useLucky(subject.luckNeeded, damageRes.event)
				subject.addBonusDamage(subject.bonusDam)
				subject.giveRegeneration(subject.regen, event)
				var particles = ObjectPool.particleOneShot(subject.rapierParticles, subject.sprite)
				particles.rotation_degrees = 180
				particles.position = Vector2( - 226, 0)
		else:
			subject.giveLucky(subject.luck, damageRes.event)
			var particles = ObjectPool.particleOneShot(subject.rapierParticles, subject.sprite)
			particles.rotation_degrees = 0
			particles.position = Vector2(284, 6)

class ForSealtheDeal:
	const Receiver = preload("res://Items/Exclusive/SealtheDeal.gd")

	static func doCooldownEffect(subject: Receiver):

		if subject.character().getRegeneration() >= subject.regenNeeded:
			var event = subject.useRegeneration(subject.regenNeeded)
			subject.giveVampirism(subject.vampirism, event)

		if subject.character().getLucky() >= subject.luckNeeded:
			var event = subject.useLucky(subject.luckNeeded)
			subject.giveSpikes(subject.spikes, event)

		if subject.character().getMana() >= subject.manaNeeded:
			var event = subject.useMana(subject.manaNeeded)
			subject.giveEmpower(subject.empower, event)

		subject.activate()

class ForSerpentStaff:
	const Receiver = preload("res://Items/Exclusive/SerpentStaff.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit() and not subject.manaUseEvents.is_empty():
			subject.damageAcc += damageRes.damage
			var curPoison = subject.damageAcc / subject.damageForPoison
			if curPoison > 0:
				subject.damageAcc %= subject.damageForPoison
				subject.inflictPoison(curPoison, damageRes.event)
			subject.manaUseEvents.pop_back()

class ForShellTotem:
	const Receiver = preload("res://Items/Exclusive/ShellTotem.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.useStamina() == Character.StaminaResult.Sufficient:
			if subject.character().getRelativeHealth() > subject.healthThreshold:
				subject.giveEmpower(1)
			else:
				subject.heal()
			subject.activate()

class ForShepherdsCrook:
	const Receiver = preload("res://Items/Exclusive/ShepherdsCrook.gd")

	static func onPrepare(subject: Receiver):
		subject.character().changeBuffProtectionChance(subject.getChance())
		subject.character().changeResistChance(Game.EventType.Blind, subject.getChance2())
		subject.character().changeResistChance(Game.EventType.Cold, subject.getChance2())

class ForSmellyBarrier:
	const Receiver = preload("res://Items/Exclusive/SmellyBarrier.gd")

	static func onPrepare(subject: Receiver):
		subject.blockAcc = 0

		for item in subject.getAffectedItems():
			if item.isA(subject.garlicDescriptor):
				item.addBonusBlock(subject.garlicBlockBonus)
			if item.canBlock():
				subject.connectForCombat(item, "gave_block", "onItemGaveBlock")

class ForSnowcake:
	const Receiver = preload("res://Items/Exclusive/Snowcake.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.inflictCold(subject.cold)
		if subject.opponent().getCold() >= subject.coldNeeded:
			subject.character().changeEffectDamageFactor(subject.effectDam)
			var dam = subject.descriptor.minDam
			var damageRes = subject.dealEffectDamage(dam)
		subject.activate()

class ForSnowStick:
	const Receiver = preload("res://Items/Exclusive/SnowStick.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			subject.inflictCold(subject.cold)
			subject.giveStacks(subject.character(), Game.EventType.Cold, subject.selfCold)
			ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)

class ForSolaris:
	const Receiver = preload("res://Items/Exclusive/Solaris.gd")

	static func onPrepare(subject: Receiver):
		subject.inventory.changeBuffAmplification_allItems(Game.EventType.Heat, subject.getChance2())

		for item in subject.getAffectedItems():
			if item.isA(subject.sunShieldDescriptor):
				subject.connectForCombat(item, "blocked", "onShieldBlocked")
			else:
				subject.connectForCombat(item, "used_heat", "onArmorUsedHeat")

class ForSpeakwithAnimals:
	const Receiver = preload("res://Items/Exclusive/SpeakwithAnimals.gd")

	static func getGatedDescriptor(subject: Receiver, rarity):
		var pets = subject.petDescriptors[rarity]
		pets.shuffle()
		for pet in pets:
			if pet in ItemBook.spiritCompanionDescriptors:
				if not ItemBook.canHaveMoreCompanions():
					continue
			return pet

class ForSpellScrollDark:
	const Receiver = preload("res://Items/Exclusive/SpellScrollDark.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.numActivations += 1
		for item in subject.getAffectedItems():
			item.addSpeed(subject.speedBonus)
		subject.giveStacks(subject.character(), Game.EventType.Blind, 1)

		if subject.numActivations == subject.maxActivations:
			subject.onAfterEffectFinished()
		else:
			subject.activate()

class ForSpellScrollFrostbolt:
	const Receiver = preload("res://Items/Exclusive/SpellScrollFrostbolt.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.uses < subject.maxUses:
			subject.uses += 1
			var dam = subject.descriptor.minDam
			var damageRes = subject.dealEffectDamage(dam)
			subject.giveStacksTemporary(subject.opponent(), Game.EventType.Cold,
				subject.coldAmount, subject.getP_m("dur_cold"), damageRes.event)
			if subject.uses == subject.maxUses:
				subject.onAfterEffectFinished()
			else:
				subject.activate()

class ForSpellScrollIce:
	const Receiver = preload("res://Items/Exclusive/SpellScrollIce.gd")

	static func onCharacterAttacked(subject: Receiver, damageRes):
		if not subject.activated:
			if damageRes.willBeLethal(subject.character()):
				var opponentCold = subject.opponent().getCold()
				if opponentCold > 0:
					subject.activated = true
					subject.opponent().loseCold(opponentCold, subject, damageRes.event)
					subject.giveBlock(round(subject.getBlock() * opponentCold), true, damageRes.event)
					subject.consume()
					ObjectPool.particleOneShot(subject.activationParticles1, subject)
					ObjectPool.particleOneShot(subject.activationParticles2, subject)

class ForSpellScrollNature:
	const Receiver = preload("res://Items/Exclusive/SpellScrollNature.gd")

	static func onItemUsedStamina(subject: Receiver, amount):
		subject.staminaAcc += amount
		var activating = false

		while subject.staminaAcc >= subject.staminaNeeded - 0.0001:
			if subject.character().getMana() >= subject.manaNeeded:
				var event = subject.useMana(subject.manaNeeded)
				subject.giveStamina(subject.stamina, event)
				subject.activate()
				activating = true
			subject.staminaAcc -= subject.staminaNeeded

		subject.showCooldownSmooth(subject.staminaAcc / subject.staminaNeeded, activating)

class ForSpicyBanana:
	const Receiver = preload("res://Items/Exclusive/SpicyBanana.gd")

	static func onStaminaUsed(subject: Receiver, amount):
		subject.staminaUsed += amount
		var healTicks = floor(subject.staminaUsed / subject.staminaForHeal)
		if healTicks > 0:
			subject.heal(healTicks * subject.getP_m("heal"))
			subject.staminaUsed -= healTicks * subject.staminaForHeal
			subject.miniActivate()

class ForSpikedStaff:
	const Receiver = preload("res://Items/Exclusive/SpikedStaff.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		var event = subject.tryUseMana(subject.manaCost)
		if event != null:
			subject.giveEmpower(subject.empower, event)
			if subject.character().isBattleRaging():
				subject.giveSpikes(subject.spikes, event)

class ForSpintoWin:
	const Receiver = preload("res://Items/Exclusive/SpintoWin.gd")

	static func doCooldownEffect(subject: Receiver):
		match subject.faceDirection:
			subject.FaceDirection.UP:
				subject.giveHeat(subject.heat)
			subject.FaceDirection.RIGHT:
				subject.giveLucky(subject.luck)
			subject.FaceDirection.DOWN:
				subject.giveRegeneration(subject.regen)
			subject.FaceDirection.LEFT:
				subject.giveMana(subject.mana)
		subject.activate()

	static func gainsStack(subject: Receiver, stackType) -> bool:
		match subject.faceDirection:
			subject.FaceDirection.UP:
				return stackType == subject.Stack.Heat
			subject.FaceDirection.RIGHT:
				return stackType == subject.Stack.Lucky
			subject.FaceDirection.DOWN:
				return stackType == subject.Stack.Regeneration
			subject.FaceDirection.LEFT:
				return stackType == subject.Stack.Mana
		return false

class ForStaffofFire:
	const Receiver = preload("res://Items/Exclusive/StaffofFire.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if subject.character().getHeat() >= subject.heatCost:
			var event = subject.tryUseMana(subject.manaCost)
			if event != null:
				subject.useHeat(subject.heatCost, event)
				subject.addBonusDamage(subject.damBonus)
				subject.numActivations += 1
				subject.activationParticles.activate()
				subject.activationParticles.process_material.scale = min(
						1.4, 0.4 + sqrt(subject.numActivations) * 0.3)

class ForStoneArmor:
	const Receiver = preload("res://Items/Exclusive/StoneArmor.gd")

	static func onDamaged(subject: Receiver, _healthChange, event):
		if subject.activated: return

		var relHealth = subject.character().getRelativeHealth()
		if relHealth < subject.healthThreshold:
			subject.activated = true
			var bl = subject.character().getMissingHealth() * subject.blockPerHealth
			subject.giveBlock(bl, true, event)
			subject.activate()

class ForStoneBadge:
	const Receiver = preload("res://Items/Exclusive/StoneBadge.gd")

	static func onShopEntered(subject: Receiver):
		var goldToSpend = subject.goldValue
		while goldToSpend > 0:
			var giftedDescriptor
			if Util.flip(0.4):
				giftedDescriptor = ItemBook.getDescriptor("Stone")
			else:
				giftedDescriptor = subject.getItemsMaxCost(goldToSpend).pick_random()

			goldToSpend -= giftedDescriptor.price

			var item = ItemBook.generateItem(giftedDescriptor)
			Game.playerNode.add_child(item)
			item.global_position = subject.global_position
			item.pushToStorage(Game.STORAGEBOX.center + Util.randInBox(100, 100))

		subject.activate()
		Game.saveRunState()

	static func getItemsMaxCost(subject: Receiver, maxCost):
		var candidates = []
		for descr in ItemBook.descriptorList:
			if (descr.price <= maxCost and
				ItemBook.canBeGenerated(descr, subject.filters)):

				candidates.push_back(descr)

		return candidates

class ForStoned:
	const Receiver = preload("res://Items/Exclusive/Stoned.gd")

	static func onPrepare(subject: Receiver):

		subject.connectForCombat(subject.character(), "character_block_changed", "onBlockChanged")
		subject.connectForCombat(subject.character(), "character_damaged", "onDamaged")
		subject.protectionActive = false
		subject.damReductionGiven = 0.0

		for item in subject.inventory.getItems():
			if subject.canAffect_global(item):
				subject.connectForCombat(item, "attacked", "onStoneAttacked")

	static func checkBlock(subject: Receiver):
		if subject.protectionActive:
			if subject.character().getBlock() == 0:
				subject.protectionActive = false

				subject.character().changeDamageResistance( - subject.damReduction)
				subject.damReductionGiven -= subject.damReduction
		else:
			if subject.character().getBlock() > 0:
				subject.protectionActive = true

				subject.character().changeDamageResistance(subject.damReduction)
				subject.damReductionGiven += subject.damReduction

class ForStoneShoes:
	const Receiver = preload("res://Items/Exclusive/StoneShoes.gd")

	static func onDamaged(subject: Receiver, _damage, event):
		if subject.hasActivated: return

		var relHealth = subject.character().getRelativeHealth()
		if relHealth < subject.healthThreshold:
			subject.hasActivated = true
			subject.giveLucky(subject.getP2(), event)
			subject.giveEmpower(subject.getP3(), event)
			subject.giveBlock(subject.getBlock(), true, event)
			subject.buffTimer.start(subject.getP_m("dur"))
			subject.setState(true)
			subject.opponent().changeTypedDamageFactor(DamageSource.Type.Ranged, - subject.damReduction)
			subject.opponent().changeEffectDamageFactor( - subject.damReduction)
			subject.consume()

class ForStrongVampiricPotion:
	const Receiver = preload("res://Items/Exclusive/StrongVampiricPotion.gd")

	static func onTriggerPotion(subject: Receiver, triggerEvent):

		var amount = subject.getP_m("lifesteal") / 100.0
		subject.curLifesteal += amount
		subject.lifestealGiven.push_back(amount)
		subject.lifestealTimer.start(subject.getP_m("dur"))
		subject.giveVampirism(subject.getP2(), triggerEvent)

	static func onOpponentDamaged(subject: Receiver, damageRes: DamageResult):
		if subject.curLifesteal > 0:
			if damageRes.hasHit() and damageRes.damageSource.canApplyLifesteal():
				subject.heal(ceil(damageRes.damage * subject.curLifesteal), damageRes.event)

class ForSunArmor:
	const Receiver = preload("res://Items/Exclusive/SunArmor.gd")

	static func reactToItemTypeChange(subject: Receiver, item):
		if item in subject.currentAffectedItems[subject.Affected.Primary]:

			if not item.hasType(subject.Type.Fire) and item.hasDynamicType(subject.Type.Holy, subject):
				subject.currentAffectedItems[subject.Affected.Primary].erase(item)
				subject.onAffectedItemRemoved(item, subject.Affected.Primary)
				return false
		return true

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getHeat() >= subject.heatNeeded:
			var event = subject.useHeat(subject.heatNeeded)
			subject.heal(subject.getP_m("heal"), event)
			subject.cleanseRandomDebuffs(subject.debuffsCleansed, event)
			EventBus.emitSignal(subject, "used_heat", [event])
		subject.activate()

class ForSunShield:
	const Receiver = preload("res://Items/Exclusive/SunShield.gd")

	static func onItemGaveBlock(subject: Receiver, amount, event):
		subject.blockAcc += amount
		var ticks = subject.blockAcc / subject.blockPerTick
		if ticks > 0:
			subject.blockAcc %= subject.blockPerTick
			var dam = ticks * (subject.damagePerTick + subject.bonusDamagePerTick)
			var damageRes = subject.dealEffectDamage(dam, event)
			subject.miniActivate()
			subject.activationParticles.activate()
