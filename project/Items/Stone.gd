extends Item

var ammunition: int
var bonusDamage: int

func _ready() -> void :
	super._ready()
	damageSource = DamageSource.new().setItem(self)
	ammunition = 1

func combatEnd():
	super.combatEnd()
	ammunition = 1

func setBagOfStones():
	ammunition = 9000

func onPreDealDamage_late(damageRes):

	preHit()

func preHit():
	removeBlock(getP1())

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/CallbacksS.gd").ForStone.doCooldownEffect(self)

func onDealtDamage(damageRes):
	if damageRes.hasHit():
		onHit()

func onHit():
	pass
