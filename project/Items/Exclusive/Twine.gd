extends Item

@onready var maxHealth = int(getP("health"))

func canAffect(item):
	return item.canActivate()

func canAffect_secondary(item):
	return item.isNeutral()

func onPrepare():
	for triggerItem in getAffectedItems():
		connectForCombat(triggerItem, "activated", "onTriggerItemActivated")

func onTriggerItemActivated(event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForTwine.onTriggerItemActivated(self, event)

