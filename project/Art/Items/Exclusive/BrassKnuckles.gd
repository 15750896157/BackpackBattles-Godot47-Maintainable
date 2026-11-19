extends Weapon

var stunParticles = load("res://Art/Items/Particles/StunParticles.tscn")

@onready var extraAccuracy = getP2()
@onready var battleRageSpeed = getP4() / 100.0

func canAffect(item):
	return item.canDamage()

func onDealtDamage(damageRes: DamageResult):
	return load("res://Code/Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBrassKnuckles.onDealtDamage(self, damageRes)

func onPrepare():
	connectForCombat(character(), "battle_rage_started", "onBattleRageStarted")
	connectForCombat(character(), "battle_rage_ended", "onBattleRageEnded")

func onBattleRageStarted(_event):
	addSpeed(battleRageSpeed)

func onBattleRageEnded(_event):
	reduceSpeed(battleRageSpeed)
