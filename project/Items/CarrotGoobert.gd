extends Goobert

@onready var empower = getP3()

@onready var particleTimer = $ParticleTimer
@onready var activationParticles = $EmpowerParticles

func onPrepare():
	setState(false)
	activationParticles.global_rotation = 0

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForCarrotGoobert.doCooldownEffect(self)

func onCombatEnd():
	particleTimer.stop()

func onParticleTimeout():
	setState(false)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(active):
	if active:
		activationParticles.activate()
	else:
		activationParticles.deactivate()
