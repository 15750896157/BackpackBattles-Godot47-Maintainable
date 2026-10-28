extends Weapon

var activationParticles = load("res://Items/Exclusive/Particles/BurningSwordActivationParticles.tscn")

var heatCounter = 0
var particleReadyTime = 0.0

@onready var heatOnHit: int = getP1()
@onready var heatNeeded: int = getP2()

func canAffect(item):
	return item.canBeEmpowered()

func onPrepare():
	heatCounter = 0
	connectForCombat(character(), "character_heat_changed", "onHeatChanged")

func onHeatChanged(amount, _event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBurningSword.onHeatChanged(self, amount, _event)

func onPreDealDamage_early(damageRes: DamageResult):
	if damageRes.hasHit() and rollChance():
		giveHeat(heatOnHit)
