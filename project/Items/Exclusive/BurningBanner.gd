extends Item

@onready var regeneration = int(getP("regen"))
@onready var buffsToRemove = int(getP("buffs"))

func canAffect(item):
	return item.hasType(Type.Holy) and item.canActivate()

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBurningBanner.onPrepare(self)

func onItemActivated(event):
	if rollChance():
		giveStacksTemporary(opponent(), Game.EventType.Blind,
			1, getP_m("dur_blind"))

func doCooldownEffect():
	removeRandomBuffs(buffsToRemove)
	giveRegeneration(regeneration)
	activate()
