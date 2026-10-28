extends Potion

@onready var healthThreshold = getP1() / 100.0
@onready var dam = getP3()
@onready var vampirism = int(getP2())

func onPrepare():

	connectForCombat(character(), "character_damaged", "onPlayerDamaged")
	connectForCombat(opponent(), "character_damaged", "onPlayerDamaged")

func onPlayerDamaged(_healthChange, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksV.gd").ForVampiricPotion.onPlayerDamaged(self, _healthChange, event)

func onTriggerPotion(triggerEvent = null):

	stealLife(dam, getP_m("lifesteal") / 100.0, triggerEvent)
	giveVampirism(vampirism, triggerEvent)
