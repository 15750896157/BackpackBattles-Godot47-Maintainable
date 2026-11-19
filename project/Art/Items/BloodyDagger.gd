extends Dagger

var activationParticles = load("res://Art/Items/Particles/BloodyDaggerActivationParticles.tscn")

var vampirismStacks: int

func canAffect(item):
	return item.hasType(Type.Vampiric)

func onPrepare():
	vampirismStacks = 0

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Code/Runtime/Callbacks/Items/CallbacksB.gd").ForBloodyDagger.onPreDealDamage_early(self, damageRes)

