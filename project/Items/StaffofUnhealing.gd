extends Item

var activationPulse = load("res://Items/Animations/UnhealingActivationPulse.tscn")

@onready var activationParticles = $ActivationParticles
@onready var unhealingTimer = $UnhealingTimer
@onready var manaCost = getP2()

var buffActive = false

func onPrepare():
	setState(false)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/CallbacksS.gd").ForStaffofUnhealing.doCooldownEffect(self)

func buffEnded():
	character().reduceUnhealing(1.0)
	setState(false)

func onCombatEnd():
	unhealingTimer.stop()

func onShopEntered():
	onStateChanged(false)

func onStateChanged(active):
	if active:
		activationParticles.activate()
	else:
		activationParticles.deactivate()

	buffActive = active
