extends Item
class_name Goobert

@onready var goobertAnimation = $Icon/GoobertAnimation
@onready var activationsToTrigger = getP1()

var activations: int

func logCooldown() -> bool:
	return true

func canAffect(item):
	return item.canActivate()

func prepare():
	activations = 0
	iterationCooldown = activationsToTrigger
	triggerTime = iterationCooldown
	Game.combatLog.snapshotItemTooltipStat(self, Stat.Cooldown)

	for item in getAffectedItems():
		connectForCombat(item, "activated", "onItemActivated")
	super.prepare()

func doCooldownEffect():
	heal()

func onItemActivated(event):
	return load("res://Runtime/Callbacks/Items/CallbacksG.gd").ForGoobert.onItemActivated(self, event)

