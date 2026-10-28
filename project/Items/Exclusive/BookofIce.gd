extends Item

@onready var manaNeeded = int(getP("mana"))
@onready var cold = int(getP("cold"))
@onready var spellSpeed = int(getP("speed")) / 100.0

func canAffect(item):
	return item.hasType(Type.Spell)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofIce.onPrepare(self)

func doCooldownEffect():
	if character().getMana() >= manaNeeded:
		var event = useMana(manaNeeded)
		inflictCold(cold, event)
	activate()
