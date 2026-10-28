extends Item

@onready var stamina = getP("stamina")
@onready var buffRefund = getP("refund_buffs") / 100.0
@onready var staminaRefund = getP("refund_stamina") / 100.0
@onready var speed = getP("speed") / 100.0
var usedStacks: Dictionary
var staminaUsed = 0.0

func canAffect(item):
	return item.isClassItem(Game.Classes_Full.Engineer)

func onPrepare():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/PerpetuumMobileBehavior.gd").onPrepare(self)

func onCombatStart():
	giveMaxStaminaTemporary(stamina, null, false)
	activate()

func onBuffChanged(amount, event):
	return load("res://Runtime/Behavior/Features/Items/Exclusive/PerpetuumMobileBehavior.gd").onBuffChanged(self, amount, event)

func onStaminaUsed(amount):
	staminaUsed += amount

func doCooldownEffect():
	return load("res://Runtime/Behavior/Features/Items/Exclusive/PerpetuumMobileBehavior.gd").doCooldownEffect(self)

