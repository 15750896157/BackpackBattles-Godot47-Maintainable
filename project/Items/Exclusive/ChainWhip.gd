extends Weapon

var buffsPurged = 0

func onPrepare():
	buffsPurged = 0
	connectToOpponentBuffs("onOpponentBuffsChanged")

func onOpponentBuffsChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForChainWhip.onOpponentBuffsChanged(self, amount, event)

func onPreDealDamage_early(damageRes: DamageResult):
	if damageRes.hasHit():
		removeRandomBuffs(getP1())
		if character().isBattleRaging():
			heal()
