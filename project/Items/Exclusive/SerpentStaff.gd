extends Weapon

@onready var manaCost = getP("mana")
@onready var permDamBonus = getP("dam")
@onready var poison = getP("poison")
@onready var damageForPoison = int(getP("damforpoison"))

var damageAcc = 0
var manaUseEvents = []

func onPrepare():
	manaUseEvents.clear()
	opponent().changeResistChance(Game.EventType.Poison, - getChance())

func onPreDealDamage_early(damageRes: DamageResult):
	var manaUseEvent = tryUseMana(manaCost)
	if manaUseEvent != null:
		addBonusDamage(permDamBonus)
		manaUseEvents.push_back(manaUseEvent)

func onDealtDamage(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSerpentStaff.onDealtDamage(self, damageRes)

