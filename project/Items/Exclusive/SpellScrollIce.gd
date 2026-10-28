extends Item

var activated: bool
var coldInflicted: int

@onready var cold = getP("cold")
@onready var maxCold = getP("max")
var activationParticles1 = load("res://Items/Exclusive/Particles/SpellScrollIceActivationParticles1.tscn")
var activationParticles2 = load("res://Items/Exclusive/Particles/SpellScrollIceActivationParticles2.tscn")

func canAffect(item):
	return item.hasType(Type.Shield) or (item.hasType(Type.Armor) and item.canActivate())

func onPrepare():
	activated = false
	connectForCombat(character(), "pre_take_damage_late", "onCharacterAttacked")

	for item in getAffectedItems():
		connectForCombat(item, "activated", "onShieldOrArmorActivated")
	coldInflicted = 0

func onCharacterAttacked(damageRes):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpellScrollIce.onCharacterAttacked(self, damageRes)

func onShieldOrArmorActivated(event):
	if coldInflicted < maxCold and rollChance():
		coldInflicted = min(cold, maxCold - coldInflicted)
		inflictCold(cold, event)
		miniActivate()
