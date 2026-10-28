extends Item

var activationParticles = load("res://Items/Exclusive/Particles/HeavyDrinkingActivationParticles.tscn")
@onready var potionSpeed = getP("speed") / 100.0

var allPotions = []
var boostedPotions = 0

func getData():
	return boostedPotions

func setData(data):
	if data != null:
		boostedPotions = data

func onBought():
	boostedPotions = 3

func isAffectingDistinct(color = Affected.Primary) -> bool:
	return color == Affected.Primary

func canAffect(item):
	return item.hasType(Type.Potion)

func canAffect_global(item):
	return item.hasType(Type.Potion)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksH.gd").ForHeavyDrinking.onPrepare(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksH.gd").ForHeavyDrinking.doCooldownEffect(self)

func onItemRoll(descr):
	if descr.hasType(Type.Potion) and boostedPotions > 0:
		ItemBook.multiplyWeight(1.5)

func onItemRolled(descr):
	if descr.hasType(Type.Potion):
		boostedPotions -= 1
