extends Weapon

var activationParticles = load("res://Items/Exclusive/Particles/SnowStickActivationParticles.tscn")

@onready var cold = int(getP("cold"))
@onready var selfCold = int(getP("cold2"))

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSnowStick.onPreDealDamage_early(self, damageRes)

