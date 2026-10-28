extends Item

@onready var luck = getP("luck")
@onready var empower = getP("empower")
@onready var damReduction = getP("damreduction") / 100.0
@onready var healthThreshold = getP1() / 100.0 - 0.0001
@onready var buffTimer = $BuffTimer
@onready var activationParticles = $ActivationParticles

var hasActivated: bool

func onPrepare():
	setState(false)
	hasActivated = false
	connectForCombat(character(), "character_damaged", "onDamaged")

func onDamaged(_damage, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForStoneShoes.onDamaged(self, _damage, event)

func onBuffTimeout():
	opponent().changeTypedDamageFactor(DamageSource.Type.Ranged, damReduction)
	opponent().changeEffectDamageFactor(damReduction)
	setState(false)

func onCombatEnd():
	buffTimer.stop()

func onShopEntered():
	onStateChanged(false)

func onStateChanged(damResActive):
	if damResActive:
		activationParticles.activate()
	else:
		activationParticles.deactivate()

func getTriggerPriority() -> int:
	return Priority.High + 3
