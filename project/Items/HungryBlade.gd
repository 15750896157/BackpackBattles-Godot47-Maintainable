extends Weapon

var activationParticles = load("res://Items/Particles/HungryBladeActivationParticles.tscn")

@onready var vampirism = int(getP1())
@onready var regenNeeded = int(getP2())
@onready var vampirismForRegen = int(getP3())

func onPrepare():
	connectForCombat(character(), "character_vampirism_changed", "onVampirismChanged")

func onCombatStart():
	giveVampirism(vampirism)
	activate(null, false, false, ActivationAni.Jump)

func onVampirismChanged(amount, _event):
	addMaxDamage(amount)

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksH.gd").ForHungryBlade.onPreDealDamage_early(self, damageRes)

