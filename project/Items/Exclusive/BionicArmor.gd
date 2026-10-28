extends Item

@onready var staminaRegenMalus = - getP("staminaregen") / 100.0
@onready var healthThreshold = getP("healtht")
@onready var maxStamina = getP("maxstamina")
@onready var staminaThreshold = getP("staminat1")
@onready var staminaUsed = getP("staminat2")
@onready var empower = int(getP("empower"))
@onready var block2 = int(getP("block"))

var blockHealthAcc: int

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBionicArmor.onPrepare(self)

func onCombatStart():
	giveBlock()
	activate()

func onHealOrBlockChanged(amount, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBionicArmor.onHealOrBlockChanged(self, amount, event)

func doCooldownEffect():
	if character().getCurrentStamina() < staminaThreshold:
		giveBlock(block2)
	else:
		useStamina(staminaUsed)
		giveEmpower(empower)
	activate()
