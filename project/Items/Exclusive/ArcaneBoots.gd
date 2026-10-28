extends Item

@onready var speedTimer = $SpeedTimer
@onready var healthThreshold = getP("healtht") / 100.0 - 0.0001
@onready var manaNeeded = int(getP("manat"))
@onready var luck = int(getP("luck"))
@onready var empower = int(getP("empower"))
@onready var bonusSpeed = getP("speed") / 100.0
var hasActivated: bool

func canAffect(item):
	return item.hasCooldown()

func onPrepare():
	hasActivated = false
	connectForCombat(character(), "character_damaged", "onDamaged")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForArcaneBoots.onDamaged(self, _damage, event)

func getTriggerPriority() -> int:
	return Priority.High + 2

func onSpeedTimerTimeout():
	for item in getAffectedItems():
		item.reduceSpeed(bonusSpeed)

func onCombatEnd():
	speedTimer.stop()
