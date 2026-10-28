extends Weapon

func canAffect(item):
	return item.gainsBuffs()

func canAffect_secondary(item):
	return item.canDamage()

func onDealtDamage(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksW.gd").ForWrench.onDealtDamage(self, damageRes)

