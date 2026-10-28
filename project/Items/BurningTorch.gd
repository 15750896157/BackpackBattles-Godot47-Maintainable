extends Weapon

var activationParticles = load("res://Items/Particles/TorchActivationParticles.tscn")
@onready var permDamBonus = getP2()

func onCombatStart():
	giveHeat(getP1())
	activate(null, false)

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBurningTorch.onPreDealDamage_early(self, damageRes)

