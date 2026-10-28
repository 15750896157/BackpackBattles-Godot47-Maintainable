extends Item

@onready var healthThreshold = getP("healtht") / 100.0 - 0.0001
@onready var empower = int(getP("empower"))
@onready var debuffs = int(getP("cleanse"))
@onready var dodges = int(getP("dodge"))

var hasActivated: bool

func onPrepare():
	hasActivated = false
	connectForCombat(character(), "character_damaged", "onDamaged")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksW.gd").ForWingedBoots.onDamaged(self, _damage, event)

func getTriggerPriority() -> int:
	return Priority.High + 2
