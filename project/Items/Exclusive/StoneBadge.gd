extends Item

@onready var goldValue = int(getP("goldvalue"))

var filters = (ItemBook.Filter.OtherClasses +
					ItemBook.Filter.Gated +
					ItemBook.Filter.Crafted +
					ItemBook.Filter.AnyRarity)

func onAddToInventory():
	ItemBook.updateClass(self)

func onAddedToStorageBox():
	ItemBook.updateClass(self)

func discard(discardGems = true):
	super.discard(discardGems)
	ItemBook.updateClass(self)

func doCooldownEffect():
	giveBlock()
	activate()

func onShopEntered():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForStoneBadge.onShopEntered(self)

func getItemsMaxCost(maxCost):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForStoneBadge.getItemsMaxCost(self, maxCost)

func getRelatedItems():
	return getItemsMaxCost(goldValue)

func getRelatedItemColumns() -> int:
	return 4
