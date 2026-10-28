extends Item

@onready var manaNeeded = int(getP3())
var manaUsed = 0

func canAffect(item):
	return item.hasType(Type.Nature)

func onPrepare():
	manaUsed = 0

	connectForCombat(character(), "character_mana_changed", "onManaChanged")

func onCombatStart():
	giveMana(getP1() * getAffectedItems().size())
	giveRegeneration(getP2() * getAffectedItems().size())
	activate()

func onManaChanged(amount, event: CombatEvent):
	return load("res://Runtime/Callbacks/Items/CallbacksY.gd").ForYggdrasilLeaf.onManaChanged(self, amount, event)

