extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForPandamonium:
	const Receiver = preload("res://Items/Pandamonium.gd")

	static func getCraftingOffset(subject: Receiver, forDirection):
		match forDirection:
			subject.FaceDirection.UP:
				return Vector2( - 1, 1)
			subject.FaceDirection.DOWN:
				return Vector2.ZERO
			subject.FaceDirection.LEFT:
				return Vector2(1, 0)
			subject.FaceDirection.RIGHT:
				return Vector2(0, - 1)

class ForPestilenceFlask:
	const Receiver = preload("res://Items/PestilenceFlask.gd")

	static func onOpponentHeal(subject: Receiver, _amount, event):
		if subject.isEmpty(): return

		subject.drink()

		subject.triggerPotion(event)

		var affected = subject.getAffectedItems()
		if not affected.is_empty():
			affected[0].triggerPotion(event)
			affected[0].miniActivate()

		subject.activate()

class ForPiercingArrow:
	const Receiver = preload("res://Items/PiercingArrow.gd")

	static func onPrepare(subject: Receiver):
		for item in subject.getAffectedItems():
			item.addCritSeverity(subject.critDam)

			subject.connectForCombat(item, "pre_deal_damage_late", "onItemAttacks")

		for item in subject.getAffectedItems(subject.Affected.Secondary):
			subject.connectForCombat(item, "activated", "onItemActivated")

class ForPoisonIvy:
	const Receiver = preload("res://Items/PoisonIvy.gd")

	static func onPrepare(subject: Receiver):
		subject.setState(false)
		subject.connectForCombat(subject.character(), "character_spikes_changed", "onSpikesChanged")
		subject.connectForCombat(subject.opponent(), "character_poison_changed", "onOpponentPoisonChanged")

		subject.character().changeDebuffResistChances(subject.getChance() * subject.getNumAffectedItems())

	static func onOpponentPoisonChanged(subject: Receiver, amount, event):
		var curPoison = subject.opponent().getPoison()

		if not subject.damageIncreaseActive and curPoison >= subject.getP1():
			subject.opponent().changeDamageResistance( - subject.getP2())
			subject.setState(true, false, event)

class ForPotionBelt:
	const Receiver = preload("res://Items/PotionBelt.gd")

	static func onPrepare(subject: Receiver):
		subject.numConsumed = 0
		subject.affectedPotions.clear()
		var affectedItems = subject.getItemsInside()
		for item in affectedItems:
			if subject.canApplyEffect(item):
				subject.affectedPotions.push_back(item)
				subject.connectForCombat(item, "potion_emptied", "onPotionEmptied")

	static func onPotionEmptied(subject: Receiver, _potion):
		var numBuffs = 0
		var active = false
		subject.numConsumed += 1

		if subject.numConsumed == 1:
			numBuffs = 1
			active = true

		elif subject.numConsumed == 4:
			subject.cleanseRandomDebuffs(subject.getP1())
			active = true

		if subject.isTypeInInventory(ItemBook.bagtacularDescriptor):
			numBuffs += int(ItemBook.bagtacularDescriptor.getP("buffs"))
			active = true

		if numBuffs > 0:
			subject.giveRandomBuffs(numBuffs)

		if active:
			subject.activate()

class ForPresent:
	const Receiver = preload("res://Items/Present.gd")

	static func onShopEntered(subject: Receiver):

		var presentPool = ItemPool.new()

		for descriptor in ItemBook.items.values():
			if ItemBook.canBeGenerated(descriptor, subject.presentFilters):
				presentPool.addItem(descriptor)
		presentPool.sortItems()

		var g = Game.getGold()
		Game.spendGold(g)

		var giftValue = ceil(g * subject.getP2())
		presentPool.setPrice(giftValue)

		while giftValue > 0:

			var giftedDescriptor
			if Util.flip(0.06):
				giftedDescriptor = ItemBook.getRandomBagDescriptor()
			else:
				giftedDescriptor = presentPool.getRandomItem()

			giftValue -= giftedDescriptor.price
			presentPool.setPrice(giftValue)

			var item = ItemBook.generateAndStorageItem(giftedDescriptor, subject.global_position)

		subject.activationParticles.global_rotation = 0
		subject.activationParticles.activate()
		subject.animation.play("GivePresent")
		Sound.playSound(subject.giveSound, - 2)
		Game.saveRunState()

class ForPumpkin:
	const Receiver = preload("res://Items/Pumpkin.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit() and subject.rollChance():
			subject.stun(subject.getP_m("dur_stun"), damageRes.event)
			var particles = ObjectPool.particleOneShot(subject.stunParticles, subject.sprite)
			particles.position = Vector2(110, - 30)
