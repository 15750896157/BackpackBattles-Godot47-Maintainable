extends Item

@onready var salesChance = getShopChance() / 100.0
@onready var manaNeeded = int(getP("manat"))
var bonusHealthFactor: int

func canAffect(item):
	return item.hasType(Type.Spell)

func onPrepare():
	bonusHealthFactor = 0
	for item in getAffectedItems():
		if item.isCrafted():
			bonusHealthFactor += 2
		else:
			bonusHealthFactor += 1

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofBasics.doCooldownEffect(self)

func onSaleRoll(item):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofBasics.onSaleRoll(self, item)

