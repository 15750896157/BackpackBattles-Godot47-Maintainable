extends Item

var activationParticlesScene = load("res://Items/Exclusive/Particles/CauldronActivationParticles.tscn")
const healColor = Color(0.384314, 0.913725, 0.423529)
const manaColor = Color(0.329412, 0.392157, 0.992157)
const heatColor = Color(0.996078, 0.458824, 0.290196)

var options: Array

func canAffect(item):
	return item.hasType(Type.Food) or item.hasType(Type.Potion)

func onPrepare():
	addSpeed(getP4() / 100.0 * getNumAffectedItems())
	options = [0, 1, 2]

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForCauldron.doCooldownEffect(self)

