extends Weapon

var stealParticles = load("res://Items/Exclusive/Particles/StealParticles.tscn")

@onready var staminaReduction = getP("stamina")

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBoomerang.onPreDealDamage_early(self, damageRes)

