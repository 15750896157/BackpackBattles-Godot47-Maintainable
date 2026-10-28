extends Weapon

var attackCounter = 0
var lastSpeedBonus = 0.0

@onready var speedPerSpike = getP1()
@onready var numHits = int(getP3())

func onPrepare():
	connectForCombat(character(), "character_spikes_changed", "onSpikesChanged")

func onSpikesChanged(_amount, _event):
	return load("res://Runtime/Callbacks/Items/CallbacksC.gd").ForClawsofAttack.onSpikesChanged(self, _amount, _event)

func onPreDealDamage_early(damageRes: DamageResult):
	if damageRes.hasHit():
		attackCounter += 1
		if attackCounter == numHits:
			giveEmpower(1)
			attackCounter = 0

func onShopEntered():
	lastSpeedBonus = 0.0
	attackCounter = 0
