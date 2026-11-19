extends Dagger

var activationParticleScene = load("res://Art/Items/Particles/MagicTorchActivationParticles.tscn")

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Code/Runtime/Callbacks/Items/CallbacksS.gd").ForSpectralDagger.onPreDealDamage_early(self, damageRes)

