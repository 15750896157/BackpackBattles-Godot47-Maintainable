extends Dagger

var activationParticles = load("res://Items/Particles/BloodyDaggerActivationParticles.tscn")

var vampirismStacks: int

func canAffect(item):
	return item.hasType(Type.Vampiric)

func onPrepare():
	vampirismStacks = 0

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBloodyDagger.onPreDealDamage_early(self, damageRes)

