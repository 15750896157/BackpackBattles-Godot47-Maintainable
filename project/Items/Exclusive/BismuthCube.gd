extends Cube

@onready var nonOxidated = $Icon/Nonoxidated
@onready var buffsNeeded = getP("buffs")
@onready var maxUses = int(getP("max"))
var numActivations = 0
var buffCounter = 0

func canAffect(item):
	return item.hasCooldown()

func _ready():
	super._ready()
	onStateChanged(maxUses)

func onPrepare():
	setState(0)
	buffCounter = 0
	affectedItem = getFirstAffectedItem()
	connectToCharacterBuffs("onBuffsChanged")

func onBuffsChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBismuthCube.onBuffsChanged(self, amount, event)

func onShopEntered():
	onStateChanged(maxUses)

func onStateChanged(_numActivations):
	numActivations = _numActivations
	nonOxidated.modulate.a = 1.0 - numActivations / float(maxUses)
