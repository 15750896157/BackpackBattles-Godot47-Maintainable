extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForItemPool:
	const Receiver = preload("res://Utility/ItemPool.gd")

	static func setPrice(subject: Receiver, price: int):
		for i in range(subject.topIndex, 0, - 1):
			if subject.sellPrice:
				if subject.pool[i].getSellPrice() <= price:
					break
			else:
				if subject.pool[i].getPrice() <= price:
					break
			subject.topIndex -= 1

	static func getItem(subject: Receiver, index):
		var item = subject.pool[index]
		if subject.deleteAfterDraw or item.canOnlyExistOnce():
			subject.removeItem(index)

		if (ItemBook.isSpiritCompanion(item) and
			not ItemBook.isItemOwned(ItemBook.spiritBellsDescriptor)):

			Util.eprint("Removing spirit companions from pool")
			for spiritCompanion in ItemBook.spiritCompanionDescriptors:
				var i = subject.pool.find(spiritCompanion)
				if i != - 1:
					subject.removeItem(i)

		return item
