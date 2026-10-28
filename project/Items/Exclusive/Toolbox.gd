extends Bag

@onready var speedReduction = getP("speedreduction") / 100.0
@onready var damBonusFactor = getP("dambonus") / 100.0

func canLockBag():
	return true

func canApplyEffect(toItem):
	return toItem.canBeEmpowered()

func onPrepare():

	connectForCombat(opponent(), "character_attacked", "onOpponentDamaged")

func onCombatStart():
	for item in getItemsInside():
		if canApplyEffect(item):
			item.reduceSpeed(speedReduction)
			item.addBonusDamageFactor(damBonusFactor)

func onOpponentDamaged(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForToolbox.onOpponentDamaged(self, damageRes)

func doCooldownEffect():
	character().startBattleRage(self, getP_m("dur_rage"))
	onAfterEffectFinished()
