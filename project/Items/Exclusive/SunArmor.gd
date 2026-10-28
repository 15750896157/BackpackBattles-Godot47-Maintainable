extends Item

@onready var heatNeeded: int = getP2()
@onready var debuffsCleansed: int = getP4()

func canAffect(item):
	return item.hasType(Type.Fire) or item.hasType(Type.Holy)

func reactToItemTypeChange(item):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSunArmor.reactToItemTypeChange(self, item)

func onAffectedItemAdded(item, color: int):
	if item.hasType(Type.Fire):
		item.addDynamicType(Type.Holy, self)

func onAffectedItemRemoved(item, color: int):
	item.removeDynamicType(Type.Holy, self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSunArmor.doCooldownEffect(self)

func onCombatStart():
	giveBlock()
	giveHeat(getNumAffectedItems() * getP1())
	activate()
