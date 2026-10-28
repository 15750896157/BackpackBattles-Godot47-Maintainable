extends Gem

const gemColor = Color(0.8, 0.8, 3)

@onready var manaNeeded = int(getP2())

var manaCounter = 0
var spectral = false

func doCooldownEffect():
	inflictCold(getP5())
	onAfterEffectFinished()

func prepareWeapon():
	return load("res://Runtime/Behavior/Features/Items/Gems/SapphireBehavior.gd").prepareWeapon(self)

func preAttack(damageRes: DamageResult):

	spectral = rollChance()
	if spectral:
		damageRes.damageSource.makeSpectral()

func onAttack(damageRes: DamageResult):
	return load("res://Runtime/Behavior/Features/Items/Gems/SapphireBehavior.gd").onAttack(self, damageRes)

func prepareArmor():
	manaCounter = 0
	connectForCombat(character(), "character_mana_changed", "onManaChanged")

func onManaChanged(amount, event):
	return load("res://Runtime/Behavior/Features/Items/Gems/SapphireBehavior.gd").onManaChanged(self, amount, event)

