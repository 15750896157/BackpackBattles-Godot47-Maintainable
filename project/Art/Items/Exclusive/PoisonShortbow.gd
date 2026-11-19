extends Weapon

var poisonParticlesScene = load("res://Art/Items/Exclusive/Particles/PoisonShortbowParticles.tscn")

@onready var poison: int = getP1()

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Code/Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPoisonShortbow.onPreDealDamage_early(self, damageRes)

