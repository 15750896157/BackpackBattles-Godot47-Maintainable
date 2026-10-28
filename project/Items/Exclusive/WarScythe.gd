extends Weapon

@onready var poisonNeeded = int(getP("poisont"))
@onready var critDamage = getP("critdam") / 100.0

func canAffect(item):
	return item.gainsStack(Stack.Poison)

func onPrepare():
	for item in getAffectedItems():
		item.giveBuffPower(Game.EventType.Poison, 1)

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksW.gd").ForWarScythe.onPreDealDamage_early(self, damageRes)

