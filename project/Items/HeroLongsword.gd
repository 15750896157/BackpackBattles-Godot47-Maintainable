extends Weapon

func canAffect(item):
	return item.canBeEmpowered()

func onCombatStart():
	for item in getAffectedItems():
		item.addBonusDamage(getP1())
	activate(null, false)

func getCraftingOffset(forDirection):
	return load("res://Runtime/Callbacks/Items/CallbacksH.gd").ForHeroLongsword.getCraftingOffset(self, forDirection)

