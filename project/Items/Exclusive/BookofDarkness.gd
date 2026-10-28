extends Item

@onready var healthNeeded = int(getP("health"))
@onready var mana = int(getP("mana"))
@onready var blind = int(getP("blind"))
@onready var spellSpeed = int(getP("speed")) / 100.0

func canAffect(item):
	return item.hasType(Type.Spell)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofDarkness.onPrepare(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofDarkness.doCooldownEffect(self)

