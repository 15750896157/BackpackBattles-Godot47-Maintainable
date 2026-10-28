extends Weapon

var blindParticles = load("res://Items/Particles/DirtParticles.tscn")

@onready var bonusDamPerMiss = int(getP1())

var broomBonusDam = 0
var onMissReadyTime = 0.0

func onPrepare():
	connectForCombat(character(), "character_attacked", "onAttacked")

func onAttacked(damageRes):
	if not damageRes.hasHit():
		addBonusDamage(bonusDamPerMiss)
		broomBonusDam += bonusDamPerMiss

func attack(event = null):
	super.attack(event)
	if broomBonusDam != 0:
		reduceBonusDamage(broomBonusDam, false)
		broomBonusDam = 0

func onDealtDamage(damageRes):
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBroom.onDealtDamage(self, damageRes)

func onShopEntered():
	broomBonusDam = 0
