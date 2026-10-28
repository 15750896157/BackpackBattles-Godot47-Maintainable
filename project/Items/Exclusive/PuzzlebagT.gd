extends Bag

@onready var refund = getP("buff") / 100.0

var usedStacks: Dictionary
var affectedInside: Array

func canApplyEffect(toItem):
	return toItem.usesBuffs()

func onPrepare():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/PuzzlebagTBehavior.gd").onPrepare(self)

func onBuffChanged(amount, event):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/PuzzlebagTBehavior.gd").onBuffChanged(self, amount, event)

func getBagEffect(number):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/PuzzlebagTBehavior.gd").getBagEffect(self, number)

