extends Item

var cogWheelAnimation = load("res://Items/Exclusive/Animations/CogCraftingAnimation.tscn")
const craftingSound = preload("res://Assets/Sound/Gears.mp3")

func canAffect(item):
	return item.isCrafted()

func onCombatStart():
	var numAffected = getNumAffectedItems()
	if numAffected > 0:
		giveBlock(getBlock() * numAffected)
		activate()

func onSold():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForCog.onSold(self)

func getSellPrice():
	return 0
