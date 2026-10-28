extends Item

@onready var critDam = getP1() / 100.0
@onready var blockRemoval = int(getP2())

func canAffect(item):
	return item.canBeEmpowered()

func canAffect_secondary(item):
	return item.canActivate()

func onPrepare():
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPiercingArrow.onPrepare(self)

func onItemAttacks(damageRes: DamageResult):
	if damageRes.wasCriticalHit():
		damageRes.damageSource.origin.removeBlock(blockRemoval)

func onItemActivated(event):
	if rollChance():
		giveLucky(1)
		miniActivate()
