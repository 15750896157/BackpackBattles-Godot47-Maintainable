extends Food

var speedBonusGiven = 0.0

@onready var speedBonus = getP2()
@onready var maxSpeedBonus = getP3()

func canAffect_global(item):
	return item.hasType(Type.Pet)

func onPrepare():
	speedBonusGiven = 0.0

	for item in inventory.getItems():
		if canAffect_global(item):
			item.giveDoubleActivationChance(getChance())

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBowlofTreats.doCooldownEffect(self)

func getGatedDescriptor(rarity) -> ItemDescriptor:
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBowlofTreats.getGatedDescriptor(self, rarity)

