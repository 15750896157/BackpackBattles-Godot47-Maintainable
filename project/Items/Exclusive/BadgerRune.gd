extends Gem

const gemColor = Color(0.845703, 0.420593, 0.062767)

@onready var attackSpeedBonus = getP("attackspeed") / 100.0
@onready var damageReduction: int = getP("damreduction")
@onready var staminaReduction = getP("stamina")

func isBattleRageItem() -> bool:
	return getGemMode() == GemMode.Armor

func prepareWeapon():
	connectForCombat(getItem(), "attacked", "onAttack")

func onAttack(damageRes: DamageResult):
	if damageRes.hasHit():
		getItem().addSpeed(attackSpeedBonus)
		miniActivate()

func prepareArmor():
	connectForCombat(character(), "pre_take_damage", "preTakeDamage")

func preTakeDamage(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBadgerRune.preTakeDamage(self, damageRes)

func hasCooldown():
	return false

func prepareInventory():
	for item in inventory.getItems():

		item.changeStaminaFactor( - staminaReduction)

func onHotSwapHoverWithGemEnd():
	gemAnimation.play("RuneShine")
