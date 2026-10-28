extends Bag

const giveSound = preload("res://Assets/Sound/Confetti3.ogg")

@onready var activationParticles = $ActivationParticles
@onready var maxStamina = getP("stamina")

var filters = (ItemBook.Filter.OtherClasses +
					ItemBook.Filter.Gated +
					ItemBook.Filter.Crafted)

func canApplyEffect(toItem):
	return toItem.isClassItem()

func onPrepare():
	for item in getAffectedItemsInside():
		connectForCombat(item, "activated", "onItemInsideActivated")

func onItemInsideActivated(event):
	giveMaxStaminaTemporary(maxStamina, event)
	miniActivate()

func onAddToInventory():
	ItemBook.updateClass(self)

func onRemoveFromInventory():
	super.onRemoveFromInventory()
	ItemBook.updateClass(self)

func onShopEntered():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBagofGiving.onShopEntered(self)

func getShopPriority() -> int:
	return Priority.Low

func getRelatedItems():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBagofGiving.getRelatedItems(self)

func getRelatedItemColumns() -> int:
	return 6

func getRelatedItemHeight() -> int:
	return 110
