extends Item

@onready var speedBonus = getP("speed") / 100.0
@onready var darkSpeed = getP("speed_dark") / 100.0
@onready var maxActivations = int(getP("max"))

var numActivations: int

func canAffect(item):
	return item.hasCooldown()

func canAffect_secondary(item):
	return item.hasType(Type.Dark)

func onPrepare():
	numActivations = 0
	addSpeed(getNumAffectedItems(Affected.Secondary) * darkSpeed)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpellScrollDark.doCooldownEffect(self)

