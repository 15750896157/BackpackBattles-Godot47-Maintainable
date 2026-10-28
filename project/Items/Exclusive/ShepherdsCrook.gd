extends Item

func canAffect(item):
	return item.canBeEmpowered()

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForShepherdsCrook.onPrepare(self)

func onCombatStart():
	for item in getAffectedItems():
		item.addBonusDamage(getP1())
	activate()
