extends "res://Items/Stone.gd"

@onready var activationParticles = $Icon/ActivationParticles
var lastFatigueDam: int

func onPrepare():
	lastFatigueDam = 0
	connectForCombat(opponent(), "fatigue_damage_changed", "onFatigueDamageChanged")
	connectForCombat(Game.combatTimer, "fatigue_damage_changed", "onFatigueDamageChanged")

func canAffect(item):
	return item.canDamage()

func onFatigueDamageChanged():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForArtifactStoneDeath.onFatigueDamageChanged(self)

func preHit():
	inflictFatigueDamage()
	activationParticles.activate()
