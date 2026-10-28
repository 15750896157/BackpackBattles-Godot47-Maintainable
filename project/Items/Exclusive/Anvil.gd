extends Item

func addToInventory(_inventory, _occupiedCells: Array, _placedByPlayer: bool):
	super.addToInventory(_inventory, _occupiedCells, _placedByPlayer)
	Game.connect("item_crafted", Callable(self, "onCraft"))

func onRemoveFromInventory():
	Game.disconnect("item_crafted", Callable(self, "onCraft"))

func onCraft(_itemDescriptor):
	var flame = ItemBook.generateItem("Flame")
	placeGeneratedItem(flame, inventory.getAdjacentCells(occupiedCells))

	activate(null, false)
	Game.saveRunState()

func canAffect(item):
	return item.isCrafted()

func canAffect_secondary(item):
	return item.isWeapon()

func onPreCombatStart():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAnvil.onPreCombatStart(self)

func getRelatedItems():
	return [ItemBook.flameDescriptor]
