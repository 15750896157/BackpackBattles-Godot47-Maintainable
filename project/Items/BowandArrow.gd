extends Bow

@onready var bonusDmgPerHit: int = getP1()
@onready var maxDmg: int = getP2()
var bonusDmg: int

func hasAttackEffect() -> bool:
	return true

func onPrepare():
	bonusDmg = 0
	setState(0)

func onWeaponAttacked(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBowandArrow.onWeaponAttacked(self, damageRes)

func onShopEntered():
	onStateChanged(0)

func onStateChanged(_bonusDmg):
	return load("res://Runtime/Callbacks/Items/CallbacksB.gd").ForBowandArrow.onStateChanged(self, _bonusDmg)

