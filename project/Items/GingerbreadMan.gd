extends Food

var activationParticlesScene = load("res://Items/Particles/GingerbreadManParticles.tscn")
@onready var luckNeeded: int = getP2()
@onready var heatNeeded: int = getP3()
@onready var manaNeeded: int = getP4()

func onCombatStart():
	giveMaxHealth()
	activate()

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/CallbacksG.gd").ForGingerbreadMan.doCooldownEffect(self)

