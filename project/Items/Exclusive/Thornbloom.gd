extends Weapon

var activationParticles = load("res://Items/Exclusive/Particles/ThornbloomActivationParticles.tscn")

@onready var spikes: int = getP("spikes")
@onready var empower: int = getP("empower")
@onready var damPerSpike = getP("damperspike")

func onPrepare():
	connectForCombat(character(), "character_empower_changed", "onEmpowerChanged")
	connectForCombat(character(), "character_spikes_changed", "onSpikesChanged")

func onSpikesChanged(amount, _event):
	changeVaryingDamage(damPerSpike * amount)

func onEmpowerChanged(amount, event):
	if amount > 0:
		giveMaxHealth(getP_m("maxhealth") * amount, event)

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForThornbloom.onPreDealDamage_early(self, damageRes)

