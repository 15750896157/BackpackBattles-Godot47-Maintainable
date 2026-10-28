extends Item

@onready var manaNeeded = int(getP("mana"))
@onready var regen = int(getP("regen"))
@onready var spellSpeed = int(getP("speed")) / 100.0

func canAffect(item):
	return item.hasType(Type.Spell)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofLight.onPrepare(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofLight.doCooldownEffect(self)

