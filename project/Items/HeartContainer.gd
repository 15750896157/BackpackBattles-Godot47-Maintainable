extends Item

@onready var regenNeeded = int(getP2())
@onready var fillAnimation = $Icon/AnimationPlayer

var activated = false

func onPrepare():
	setState(false)
	connectForCombat(character(), "character_regeneration_changed", "onRegenChanged")

func doCooldownEffect():
	giveRegeneration(getP1())
	activate()

func onRegenChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/CallbacksH.gd").ForHeartContainer.onRegenChanged(self, amount, event)

func onShopEntered():
	onStateChanged(false)

func onStateChanged(filled):
	if activated == filled: return
	activated = filled

	if filled:
		fillAnimation.play("Appear")
		fillAnimation.queue("Idle")
	else:
		fillAnimation.play("Disappear")
