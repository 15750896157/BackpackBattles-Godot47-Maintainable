extends Weapon

var activationPulse = load("res://Items/Animations/BlindPulse.tscn")

@onready var blindingLightTimer = $BlindingLightTimer
@onready var activationParticles = $ActivationParticles
@onready var regenNeeded = int(getP("regent"))

@onready var blind = int(getP("blind"))
@onready var damPerBlind = getP("dam_blind")

func onPrepare():
	return load("res://Runtime/Behavior/Features/Items/LightsaberBehavior.gd").onPrepare(self)

func inflict(duration, event):
	giveStacksTemporary(opponent(), Game.EventType.Blind,
			blind, duration, event)

func onRegenChanged(amount, triggerEvent):
	return load("res://Runtime/Behavior/Features/Items/LightsaberBehavior.gd").onRegenChanged(self, amount, triggerEvent)

func onOpponentBlindChanged(amount, event):
	changeVaryingDamage(damPerBlind * amount)

func onCombatEnd():
	blindingLightTimer.stop()

func onBlindingLightTimeout():
	setState(false)

	Util.callNextFrame(character(), "endBlindingLight")

func onBlindingLightEnded(event):
	onRegenChanged(0, event)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(active):
	if active:
		activationParticles.activate()
	else:
		activationParticles.deactivate()
