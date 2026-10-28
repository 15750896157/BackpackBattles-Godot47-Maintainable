extends Item

@onready var foodPotionSpeed = getP("speed") / 100.0
@onready var heat = int(getP("heat"))
@onready var regen = int(getP("regen"))

var numFood: int

func canAffect(item):
	return item.hasType(Type.Potion)

func canAffect_secondary(item):
	return item.hasType(Type.Food)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPot.onPrepare(self)

func doCooldownEffect():
	giveHeat(heat)
	giveRegeneration(regen)
	onAfterEffectFinished()

func onPotionTriggered(_potion):
	heal(getP_m("heal") + getP_m("heal_food") * numFood)
