extends Item

@onready var staminaNeeded = getP("staminat")
@onready var stamina = getP("stamina")
@onready var manaNeeded = getP("mana")

var staminaAcc: float

func canAffect(item):
	return item.canUseStamina()

func onPrepare():
	staminaAcc = 0.0
	for item in getAffectedItems():
		connectForCombat(item, "used_stamina", "onItemUsedStamina")

func onItemUsedStamina(amount):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpellScrollNature.onItemUsedStamina(self, amount)

