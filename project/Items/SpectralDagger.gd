extends Dagger

var activationParticleScene = load("res://Items/Particles/MagicTorchActivationParticles.tscn")

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksS.gd").ForSpectralDagger.onPreDealDamage_early(self, damageRes)

