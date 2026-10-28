extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCarrotGoobert:
	const Receiver = preload("res://Items/CarrotGoobert.gd")

	static func doCooldownEffect(subject: Receiver):
		subject.setState(true, true)
		subject.cleanseRandomDebuffs(subject.getP2())
		var duration = subject.getP_m("dur")
		subject.giveStacksTemporary(subject.character(), Game.EventType.Empower,
			subject.empower, duration)
		subject.particleTimer.stop()
		subject.particleTimer.start(duration)

class ForClawsofAttack:
	const Receiver = preload("res://Items/ClawsofAttack.gd")

	static func onSpikesChanged(subject: Receiver, _amount, _event):
		var clawsBonus = min(subject.speedPerSpike * subject.character().getSpikes(), subject.getP2())
		clawsBonus /= 100.0
		subject.addSpeed(clawsBonus - subject.lastSpeedBonus)
		subject.lastSpeedBonus = clawsBonus

class ForCorruptedArmor:
	const Receiver = preload("res://Items/CorruptedArmor.gd")

	static func reactToItemTypeChange(subject: Receiver, item):
		if item in subject.currentAffectedItems[subject.Affected.Primary]:

			if not item.hasType(subject.Type.Holy) and item.hasDynamicType(subject.Type.Dark, subject):
				subject.currentAffectedItems[subject.Affected.Primary].erase(item)
				subject.onAffectedItemRemoved(item, subject.Affected.Primary)
				return false
		return true

	static func doCooldownEffect(subject: Receiver):
		var cleansedDebuffs = subject.pickRandomStacks(Game.getDebuffs(), subject.movedDebuffs, subject.character())

		for debuff in cleansedDebuffs:
			var event = subject.character().loseStacks(debuff, cleansedDebuffs[debuff], subject)
			if event:
				var actuallyCleansed = - event.getAmount()
				subject.giveStacks(subject.opponent(), debuff, actuallyCleansed, event)

		subject.activate()

class ForCritwoodStaff:
	const Receiver = preload("res://Items/CritwoodStaff.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if subject.character().getMana() >= subject.manaCost:
			if not subject.buffActive:
				subject.setState(true, true)
				for item in subject.inventory.getItems():
					item.addCritChancePercent(100)

			subject.useMana(subject.manaCost)
			damageRes.damage += subject.tempDamBonus
			var critBuffDur = subject.getP_m("dur")
			Util.changeTimer(subject.critTimer, critBuffDur)
			Util.createPulse(subject.activationPulse, subject, subject.get_node("Icon/PulsePosition").global_position)

class ForCrossblades:
	const Receiver = preload("res://Items/Crossblades.gd")

	static func onCombatStart(subject: Receiver):
		for item in subject.getAffectedItems(subject.Affected.Primary):
			item.addBonusDamage(subject.getP1())

		for item in subject.getAffectedItems(subject.Affected.Secondary):
			item.addSpeed(subject.getP2() / 100.0)

		subject.activate(null, false)

	static func getCraftingOffset(subject: Receiver, forDirection):
		match forDirection:
			subject.FaceDirection.UP:
				return Vector2( - 1, 0)
			subject.FaceDirection.DOWN:
				return Vector2( - 1, 0)
			subject.FaceDirection.LEFT:
				return Vector2(0, - 1)
			subject.FaceDirection.RIGHT:
				return Vector2(0, - 1)

class ForCursedDagger:
	const Receiver = preload("res://Items/CursedDagger.gd")

	static func onOpponentDebuffsChanged(subject: Receiver, amount, _event):
		var extraCritChance = amount * subject.getChance()
		var extraAccuracy = amount * subject.getP2()
		subject.addCritChancePercent(extraCritChance)
		subject.addAccuracy(extraAccuracy)

		for item in subject.getAffectedItems():
			item.addCritChancePercent(extraCritChance)
			if item.isWeapon():
				item.addAccuracy(extraAccuracy)

class ForCursedHairComb:
	const Receiver = preload("res://Items/CursedHairComb.gd")

	static func onAffectedAttacked(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var bonusLifesteal = subject.getNumAffectedItems(subject.Affected.Secondary) * subject.getP_m("lifesteal_scaling")
			subject.heal(ceil(damageRes.damage * (subject.getP_m("lifesteal") + bonusLifesteal) / 100.0),
				damageRes.event)
