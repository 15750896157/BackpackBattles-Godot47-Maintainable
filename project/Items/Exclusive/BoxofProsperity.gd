extends Bag

@onready var activeParticles = $Icon/ActiveParticles
@onready var activationParticles = $Icon/ActivationParticles
@onready var requiredItems = getP("insideitems")

func canApplyEffect(toItem):
	return toItem.getRarity() >= Rarity.Godly

func onShopEntered():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBoxofProsperity.onShopEntered(self)

func onAffectedItemInsideAdded(_item):
	if getNumAffectedInside() == requiredItems:
		activationParticles.activate()
		activeParticles.activate()

func onItemRemoved(item):
	super.onItemRemoved(item)
	if not conditionFulfilled():
		activeParticles.deactivate()

func conditionFulfilled() -> bool:
	return getNumAffectedInside() >= requiredItems

func onRemoveFromInventory():
	activeParticles.deactivate()

func onAddToInventory():
	if conditionFulfilled():
		activeParticles.activate()

func discard(withGems = true):
	activationParticles.instantClear()
	activeParticles.instantClear()
	super.discard(withGems)
