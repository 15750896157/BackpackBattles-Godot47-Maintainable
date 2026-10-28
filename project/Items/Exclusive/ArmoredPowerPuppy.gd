extends "res://Items/Exclusive/PowerPuppy.gd"

func canAffect(item):
	return item.hasType(Type.Food) or item.hasType(Type.Pet)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForArmoredPowerPuppy.onPrepare(self)

