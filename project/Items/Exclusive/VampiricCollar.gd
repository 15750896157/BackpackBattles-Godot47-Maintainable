extends RangerCollar

@onready var maxLifesteal = getP("max") / 100.0
var affectedItems_dict: Dictionary

func canAffect(item):
	return item.canDamage()

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksV.gd").ForVampiricCollar.onPrepare(self)

func onVampirismChanged(amount, event):
	for item in affectedItems:
		item.changeCritChancePercent(amount * getChance())

func onOpponentAttacked(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksV.gd").ForVampiricCollar.onOpponentAttacked(self, damageRes)

