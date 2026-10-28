extends Item

var damageIncreaseActive = false

@onready var activationParticles = $ActivationParticles
@onready var poisonPerSpike: int = getP4()

func canAffect(item):
	return item.hasType(Type.Nature)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPoisonIvy.onPrepare(self)

func onSpikesChanged(amount, event):
	if amount > 0:
		inflictPoison(amount * poisonPerSpike, event)
		miniActivate()

func onOpponentPoisonChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPoisonIvy.onOpponentPoisonChanged(self, amount, event)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(active):
	if active:
		activationParticles.activate()
	else:
		activationParticles.deactivate()

	damageIncreaseActive = active
