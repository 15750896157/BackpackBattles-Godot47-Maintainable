extends Bag

@onready var mana = int(getP("mana"))

func canApplyEffect(toItem):
	return toItem.gainsStack(Stack.Mana)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForScholarBag.onPrepare(self)

func onCombatStart():
	giveMana(mana)
	activate()
