extends Cube

@onready var healthThreshold = getP("healtht") / 100.0 - 0.0001
@onready var healReduction = getP("healreduction") / 100.0
var hasActivated: bool

func canAffect(item):
	return item.hasCooldown()

func onPrepare():
	hasActivated = false
	affectedItem = getFirstAffectedItem()
	connectForCombat(opponent(), "character_damaged", "onDamaged")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForChromeCube.onDamaged(self, _damage, event)

