extends Item

@onready var movedDebuffs: int = getP1()

func canAffect(item):
	return item.hasType(Type.Dark) or item.hasType(Type.Holy)

func reactToItemTypeChange(item):
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCorruptedArmor.reactToItemTypeChange(self, item)

func onAffectedItemAdded(item, color: int):
	if item.hasType(Type.Holy) and not item.hasType(Type.Dark):
		item.addDynamicType(Type.Dark, self)

func onAffectedItemRemoved(item, color: int):
	item.removeDynamicType(Type.Dark, self)

func onCombatStart():
	giveBlock()
	var debuffProtectionChance = getChance() * getNumAffectedItems()
	opponent().changeDebuffProtectionChance(debuffProtectionChance)
	activate()

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCorruptedArmor.doCooldownEffect(self)

