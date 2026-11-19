extends Dagger

var activationParticles = load("res://Art/Items/Particles/CursedDaggerActivationParticles.tscn")

func canAffect(item):
	return item.canDamage()

func onPrepare():
	connectToOpponentDebuffs("onOpponentDebuffsChanged")

func onPreDealDamage_early(damageRes: DamageResult):
	if damageRes.hasHit():
		inflictRandomDebuffs(getP1())
		ObjectPool.particleOneShot(activationParticles, sprite)

func onOpponentDebuffsChanged(amount, _event):
	return load("res://Code/Runtime/Callbacks/Items/CallbacksC.gd").ForCursedDagger.onOpponentDebuffsChanged(self, amount, _event)

