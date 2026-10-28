extends Item

@onready var speedTimer = $SpeedTimer
@onready var speedPerTrigger = getP("speed") / 100.0
@onready var maxSpeed = getP("max") / 100.0
var speedUpItem = null

func canAffect(item):
	return item.canActivate()

func canAffect_secondary(item):
	return item.hasCooldown()

func onPrepare():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/RopeBehavior.gd").onPrepare(self)

func onTriggerItemActivated(event):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/RopeBehavior.gd").onTriggerItemActivated(self, event)

func onSpeedTimeout():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/RopeBehavior.gd").onSpeedTimeout(self)

func onCombatEnd():
	speedTimer.stop()
	speedUpItem = null
