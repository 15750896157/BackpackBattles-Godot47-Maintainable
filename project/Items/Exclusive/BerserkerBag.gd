extends Bag

@onready var healthThreshold = getP("healtht") / 100.0 - 0.0001
@onready var battleRageSpeed = getP("speed_rage") / 100.0
@onready var damageResistance = getP("damresistance")
var activated = false

func canApplyEffect(toItem):
	return toItem.hasCooldown()

func onPrepare():
	activated = false
	connectForCombat(character(), "character_damaged", "onDamaged")
	connectForCombat(character(), "battle_rage_started", "onBattleRageStarted")
	connectForCombat(character(), "battle_rage_ended", "onBattleRageEnded")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBerserkerBag.onDamaged(self, _damage, event)

func onBattleRageStarted(_event):
	character().changeDamageResistance(damageResistance)
	for item in getItemsInside():
		if canApplyEffect(item):
			item.addSpeed(battleRageSpeed)

func onBattleRageEnded(_event):
	character().changeDamageResistance( - damageResistance)
	for item in getItemsInside():
		if canApplyEffect(item):
			item.reduceSpeed(battleRageSpeed)

func getTriggerPriority() -> int:
	return Priority.High + 10
