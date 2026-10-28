extends Potion

func onTriggerPotion(triggerEvent = null):
	inflictPoison(getP1(), triggerEvent)
	selfInflictPoison(getP2(), triggerEvent)

func onPrepare():
	connectForCombat(opponent(), "character_healed", "onOpponentHeal")

func onOpponentHeal(_amount, event):
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPestilenceFlask.onOpponentHeal(self, _amount, event)

