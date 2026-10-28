extends Weapon

@onready var buffParticles = $Icon/BuffParticles

@onready var empowerNeeded = int(getP1())
@onready var buffedStamina = getP2()
@onready var buffedCooldown = getP3()
var buffed = false

func isBuffed():
	return buffed

func getStaminaCost() -> float:
	var override = statDisplayOverrides[Stat.StaminaCost]
	if override: return override

	if isBuffed():
		return buffedStamina * staminaFactor
	else:
		return super.getStaminaCost()

func onPrepare():
	setState(false)
	connectForCombat(character(), "character_empower_changed", "empowerChanged")

func empowerChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/CallbacksG.gd").ForGreatsword.empowerChanged(self, amount, event)

func onShopEntered():
	onStateChanged(false)
	buffParticles.deactivate()

func onStateChanged(_buffed):
	buffed = _buffed
	if buffed:
		buffParticles.activate()
	else:
		buffParticles.deactivate()
