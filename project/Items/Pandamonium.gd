extends Weapon

func canAffect(item):
	return item.hasType(Type.Food)

func onPrepare():
	for item in getAffectedItems():
		connectForCombat(item, "activated", "onFoodActivated")

	opponent().changePoisonCritChancePercent(getNumAffectedItems() * getChance())

func onFoodActivated(event):

	inflictPoison(getP1())

func getCraftingOffset(forDirection):
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPandamonium.getCraftingOffset(self, forDirection)

