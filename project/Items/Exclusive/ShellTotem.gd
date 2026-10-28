extends Item

@onready var healthThreshold = getP("healtht") / 100.0

func canAffect(item):
	return item.hasType(Type.Holy)

func onPrepare():
	changeStaminaFactor( - getP("stamina") * getNumAffectedItems())

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForShellTotem.doCooldownEffect(self)

