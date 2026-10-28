extends Weapon

func canAffect(item):
	return item.canBeEmpowered()

func canAffect_secondary(item):
	return item.hasCooldown()

func onCombatStart():
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCrossblades.onCombatStart(self)

func onPreDealDamage_early(damageRes: DamageResult):
	if damageRes.hasHit():
		addBonusDamage(getP3())
		addSpeed(getP4() / 100.0)

func getCraftingOffset(forDirection):
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCrossblades.getCraftingOffset(self, forDirection)

