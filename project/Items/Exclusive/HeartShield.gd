extends Shield

@onready var fillAnimation = $Icon/AnimationPlayer
@onready var healamp = getP("healamp") / 100.0
@onready var blockFactor = getP("block") / 100.0
@onready var regenNeeded = int(getP("regent"))
@onready var regenOnBlock = int(getP("regen"))
@onready var regenMax = int(getP("max_regen"))
var activated = false
var regenGiven: int

func canAffect(item):
	return (item.canBlock() or
			item.canHealOrLifesteal() or
			item.gainsStack(Stack.Regeneration))

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksH.gd").ForHeartShield.onPrepare(self)

func afterBlock():
	drainStamina(getP2(), blockedDamageRes.event)

	if regenGiven < regenMax:
		giveRegeneration(regenOnBlock, blockedDamageRes.event)
		regenGiven += regenOnBlock
	activate()

func onRegenChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksH.gd").ForHeartShield.onRegenChanged(self, amount, event)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(filled):
	if activated == filled: return
	activated = filled

	if filled:
		fillAnimation.play("Activate")
	else:
		fillAnimation.play("Deactivate")

func preTakeDamage(damageRes: DamageResult):
	if activated:
		if damageRes.damageSource.isAttackOrEffect() and rollChance():
			blockedDamageRes = damageRes
			beforeBlock()
	else:
		super.preTakeDamage(damageRes)
