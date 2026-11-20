extends Weapon

var stunParticles = load("res://Art/Items/Particles/StunParticles.tscn")

func onDealtDamage(damageRes: DamageResult):
	return load("res://Code/Runtime/Callbacks/Items/CallbacksH.gd").ForHammer.onDealtDamage(self, damageRes)

func onFusingAsCatalystFinished():
	super.onFusingAsCatalystFinished()
	playActivationAnimation()
