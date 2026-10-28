extends Item

@onready var spikes = int(getP("spikes"))
@onready var heat = int(getP("heat"))
@onready var spikesNeeded = int(getP("spikest"))
@onready var heatForSpikes = int(getP("heat2"))

var spikesAcc = 0
var affectedItemsDict: Dictionary

func canAffect(item):
	return item.gainsStack(Stack.Spikes)

func onPrepare():
	spikesAcc = 0
	affectedItemsDict = Util.arrayAsIndexDict(getAffectedItems())

	connectForCombat(character(), "character_spikes_changed", "onSpikesChanged")

func onSpikesChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBurningSpikes.onSpikesChanged(self, amount, event)

func onCombatStart():
	giveSpikes(spikes)
	giveHeat(heat)
	activate()
