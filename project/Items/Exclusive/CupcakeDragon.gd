extends Weapon

@onready var buffRemoval = int(getP("remove"))
@onready var buffGain = int(getP("gain"))
@onready var speedPerFood = getP("speed") / 100.0

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForCupcakeDragon.onPreDealDamage_early(self, damageRes)

func canAffect(item):
	return item.hasType(Type.Food)

func onPrepare():
	addSpeed(speedPerFood * getNumAffectedItems())
