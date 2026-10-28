extends Item

@onready var regenNeeded = int(getP("regen"))
@onready var lucky = int(getP("luck"))
@onready var spikes = int(getP("spikes"))
@onready var spellSpeed = int(getP("speed")) / 100.0

func canAffect(item):
	return item.hasType(Type.Spell)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBookofNature.onPrepare(self)

func doCooldownEffect():
	if character().getRegeneration() >= regenNeeded:
		var event = useRegeneration(regenNeeded)
		giveLucky(lucky, event)
		giveSpikes(spikes, event)
	activate()
