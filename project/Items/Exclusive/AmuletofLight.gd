extends Item

@onready var regenOnActivate = int(getP("regen"))

const amuletColor = Color(1, 0.850098, 0.400391)

func _ready():
	super._ready()
	specificDragParticles[0].self_modulate = amuletColor

func canAffect(item):
	return item.canActivate()

func onPrepare():
	connectForCombat(character(), "character_regeneration_changed", "onRegenChanged")

	for item in getAffectedItems():
		connectForCombat(item, "activated", "onItemActivated")

func onItemActivated(event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAmuletofLight.onItemActivated(self, event)

func onRegenChanged(amount, event):
	if amount > 0:
		giveMaxHealth(amount * getP_m("maxhealth"), event)
