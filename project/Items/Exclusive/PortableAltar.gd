extends Bag

const valueFactor = 1.0
var pool = ItemPool.new()
var filters = ItemBook.Filter.Amulets

func _ready():
	super._ready()
	CraftingManager.connect("recipes_updated", Callable(self, "onRecipesUpdated"))

func canLockBag():
	return true

func showBagBorderForItem(item):
	return not item.isBag()

func onCombatStart():
	giveEmpower(getP("empower"))
	activate()

func onRecipesUpdated():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPortableAltar.onRecipesUpdated(self)

func readyToFuse() -> bool:
	return not bondedIngredients.is_empty()

func onFusingFinished(validBonds):
	super.onFusingFinished(validBonds)
	var value = 0
	for item in validBonds:
		value += item.getPrice()

	if value == 0:
		return

	value -= 1
	var flame = ItemBook.generateAndStorageItem("Flame", global_position)

	if value > 0:

		value = round(value * valueFactor)

		var excluded = {}
		for item in validBonds:
			excluded[item.descriptor] = true

		pool.resetPool()
		for descr in ItemBook.items.values():
			if (ItemBook.canBeGenerated(descr, filters) and
				not descr in excluded):
				pool.addItem(descr)

		pool.pool.shuffle()
		pool.sortItems()

		while value > 0:
			pool.setPrice(value)
			var item = pool.getRandomItemTopHeavy()
			value -= item.price

			ItemBook.generateAndStorageItem(item, global_position)

	activate()
	Game.saveRunState()
	Game.saveGame()

func getCounterValue() -> int:
	var gold = 0
	for item in bondedIngredients:
		gold += item.getPrice()
	return gold
