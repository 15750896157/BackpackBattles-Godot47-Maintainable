extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Piggybank.gd")

static func explodeRandomly(subject: Receiver):
	if not subject.isBaseItem() and not subject.isBoundAsIngredient() and subject.hasPinata():
		if Util.flipPercent(subject.piggyPinataDescriptor.shopChance):
			subject.explode()
			subject.inventory.removeItem(subject)
			subject.discard()

static func explode(subject: Receiver):
	var particles = ObjectPool.particleOneShot(subject.breakParticles, subject.get_parent())
	particles.global_position = subject.global_position
	Sound.playSound(subject.breakSound)

	if subject.hasPinata():
		var pool = ItemPool.new()
		for descr in ItemBook.items.values():
			if (descr != subject.descriptor and
				ItemBook.canBeGenerated(descr, subject.pinataFilter)):

				pool.addItem(descr)

		pool.pool.shuffle()
		pool.sortItems()
		pool.sellPrice = true

		var value = 7

		while value > 0:
			pool.setPrice(value)
			var item = pool.getRandomItemTopHeavy()
			value -= item.getSellPrice()

			ItemBook.generateAndStorageItem(item, subject.global_position)
