extends "res://Items/Bag.gd"

var affectedPotions: Array
var numConsumed: int

func onPrepare():
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPotionBelt.onPrepare(self)

func onPotionEmptied(_potion):
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPotionBelt.onPotionEmptied(self, _potion)

func canApplyEffect(toItem):
	return toItem.hasType(Type.Potion)
