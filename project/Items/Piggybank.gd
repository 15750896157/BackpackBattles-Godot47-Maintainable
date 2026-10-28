extends Item

const breakSound = preload("res://Assets/Sound/JarBreaking.ogg")
var breakParticles = load("res://Items/Particles/PiggyBreakParticles.tscn")

@onready var piggyPinataDescriptor = ItemBook.getDescriptor("Piggy Pinata")
@onready var hammerDescriptor = ItemBook.getDescriptor("Hammer")
@onready var thorsHammerDescriptor = ItemBook.getDescriptor("Thors Hammer")

func onShopEntered():
	giveGold(getP1())
	explodeRandomly()

func explodeRandomly():
	return load("res://Runtime/Behavior/Features/Items/PiggybankBehavior.gd").explodeRandomly(self)

func canAffect(item):
	return item.hasStartofBattle()

func onCombatStart():
	giveMaxHealth(getP_m("maxhealth") * getNumAffectedItems())
	consume()

func hasPinata() -> bool:
	return ItemBook.isItemInInventory(piggyPinataDescriptor)

func isSmashRecipe() -> bool:
	return (curRecipe.ingredients[0] == hammerDescriptor or
			curRecipe.ingredients[0] == thorsHammerDescriptor)

func getFusionItemName() -> String:
	if isSmashRecipe() and hasPinata():
		return Util.tr("Piggy Pinata_CRAFT")
	return super.getFusionItemName()

func allowGeneratingFusionItem() -> bool:
	if isSmashRecipe() and hasPinata():
		return false
	return true

var pinataFilter = ItemBook.Filter.Gems + ItemBook.Filter.Amulets

func explode():
	return load("res://Runtime/Behavior/Features/Items/PiggybankBehavior.gd").explode(self)

func finishFusing():

	if isSmashRecipe():
		explode()

	super.finishFusing()

func getShopPriority() -> int:
	return Priority.Lowest
