extends Potion

@onready var healingReductionTimer = $HealingReductionTimer
@onready var healingDebuff = getP3() / 100.0
@onready var damPerDebuff = getP("dam")
@onready var playerHealthThreshold = getP("ownhpt") / 100.0 - 0.0001
@onready var opponentHealthThreshold = getP("opphpt") / 100.0 - 0.0001

func canDamage() -> bool:
	return true

func onTriggerPotion(triggerEvent = null):
	return load("res://Runtime/Callbacks/Items/CallbacksS.gd").ForStrongDemonicFlask.onTriggerPotion(self, triggerEvent)

func onPrepare():
	connectForCombat(character(), "character_damaged", "onPlayerDamaged")
	connectForCombat(opponent(), "character_damaged", "onOpponentDamaged")

func onPlayerDamaged(healthChange, event):
	if isEmpty(): return
	if character().getRelativeHealth() < playerHealthThreshold:
		drinkStrongDemonicFlask(event)

func onOpponentDamaged(healthChange, event):
	if isEmpty(): return
	if opponent().getRelativeHealth() < opponentHealthThreshold:
		drinkStrongDemonicFlask(event)

func drinkStrongDemonicFlask(event):
	return load("res://Runtime/Callbacks/Items/CallbacksS.gd").ForStrongDemonicFlask.drinkStrongDemonicFlask(self, event)

func healingReductionTimeout():
	opponent().addHealingEfficiency(healingDebuff)

func onCombatEnd():
	healingReductionTimer.stop()
