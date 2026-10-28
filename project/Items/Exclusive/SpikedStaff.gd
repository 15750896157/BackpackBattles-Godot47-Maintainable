extends Weapon

@onready var manaCost = getP("mana")
@onready var empower = getP("empower")
@onready var spikes = getP("spikes")

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpikedStaff.onPreDealDamage_early(self, damageRes)

