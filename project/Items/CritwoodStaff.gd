extends Weapon

var activationPulse = load("res://Items/Animations/CritPulse.tscn")

@onready var activationParticles = $ActivationParticles
@onready var critTimer = $CritBuffTimer
@onready var manaCost = getP1()
@onready var tempDamBonus = getP2()

var buffActive = false

func onPrepare():
	setState(false)

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCritwoodStaff.onPreDealDamage_early(self, damageRes)

func buffEnded():
	for item in inventory.getItems():
		item.reduceCritChancePercent(100)
	setState(false)

func onCombatEnd():
	critTimer.stop()

func onShopEntered():
	onStateChanged(false)

func onStateChanged(active):
	if active:
		activationParticles.activate()
	else:
		activationParticles.deactivate()

	buffActive = active
