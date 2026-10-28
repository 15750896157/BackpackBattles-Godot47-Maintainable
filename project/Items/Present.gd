extends Item

const giveSound = preload("res://Assets/Sound/Confetti3.ogg")

var presentFilters = (ItemBook.Filter.OtherClasses +
							ItemBook.Filter.Gated +
							ItemBook.Filter.Crafted +
							ItemBook.Filter.AnyRarity +
							ItemBook.Filter.IgnoreWeight)

@onready var activationParticles = $ActivationParticles

func onCombatStart():
	giveRandomBuffs(getP1())
	activate()

func onShopEntered():
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPresent.onShopEntered(self)

func getShopPriority() -> int:
	return Priority.Low + 1
