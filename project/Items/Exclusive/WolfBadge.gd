extends Item

@onready var healthThreshold = getP1() / 100.0 - 0.0001
@onready var battleRageSpeed = getP3() / 100.0
@onready var battleRageDamReduction = getP4()
var activated = false

func onAddToInventory():
	ItemBook.updateClass(self)

func onRemoveFromInventory():
	ItemBook.updateClass(self)

func canAffect(item):
	return item.hasCooldown()

func onPrepare():
	activated = false
	connectForCombat(character(), "character_damaged", "onDamaged")
	connectForCombat(character(), "battle_rage_started", "onBattleRageStarted")
	connectForCombat(character(), "battle_rage_ended", "onBattleRageEnded")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksW.gd").ForWolfBadge.onDamaged(self, _damage, event)

func onBattleRageStarted(_event):
	character().changeDamageResistance(battleRageDamReduction)
	for item in getAffectedItems():
		item.addSpeed(battleRageSpeed)

func onBattleRageEnded(_event):
	character().changeDamageResistance( - battleRageDamReduction)
	for item in getAffectedItems():
		item.reduceSpeed(battleRageSpeed)

func getTriggerPriority() -> int:
	return Priority.High + 10

func getRelatedItems():
	return ItemBook.getShopItemsForClass(Game.Classes_Full.Berserker)
