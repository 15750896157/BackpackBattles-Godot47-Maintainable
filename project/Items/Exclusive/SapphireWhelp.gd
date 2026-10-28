extends Weapon

var stackTypes

func _ready():
	super._ready()
	stackTypes = Game.getBuffs()
	stackTypes.erase(Game.EventType.Mana)

func onCombatStart():
	giveMana(getP1())
	activate(null, false)

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSapphireWhelp.onPreDealDamage_early(self, damageRes)

