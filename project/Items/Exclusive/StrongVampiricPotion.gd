extends "res://Items/Exclusive/VampiricPotion.gd"

@onready var lifestealTimer = $LifestealTimer
@onready var lifestealPerTrigger = getP3() / 100.0
var curLifesteal: float
var lifestealGiven: Array

func onPrepare():
	super.onPrepare()
	curLifesteal = 0.0
	lifestealGiven.clear()
	connectForCombat(opponent(), "character_attacked", "onOpponentDamaged")

func onTriggerPotion(triggerEvent = null):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForStrongVampiricPotion.onTriggerPotion(self, triggerEvent)

func onOpponentDamaged(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForStrongVampiricPotion.onOpponentDamaged(self, damageRes)

func onLifestealTimeout():
	curLifesteal -= lifestealGiven.pop_front()

func onCombatEnd():
	lifestealTimer.stop()
