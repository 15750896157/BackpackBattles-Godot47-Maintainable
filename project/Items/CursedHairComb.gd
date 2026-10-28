extends Item

func canAffect(item):
	return item.canBeEmpowered()

func canAffect_secondary(item):
	return item.hasType(Type.Vampiric)

func onPrepare():
	character().addHealingEfficiency(getP3() / 100.0)

	for weapon in getAffectedItems():
		connectForCombat(weapon, "attacked", "onAffectedAttacked")

func onCombatStart():
	giveVampirism(getP1())
	activate()

func onAffectedAttacked(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCursedHairComb.onAffectedAttacked(self, damageRes)

