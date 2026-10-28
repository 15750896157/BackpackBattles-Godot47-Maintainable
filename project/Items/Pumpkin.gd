extends Food

const glowingTexture = preload("res://Items/Sprites/Pumpkin_glowing.png")
var stunParticles = load("res://Items/Particles/StunParticles.tscn")

@onready var heat = int(getP("heat"))
@onready var normalTexture = sprite.texture

func _ready() -> void :
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func doCooldownEffect():
	if useStamina() == Character.StaminaResult.Sufficient:
		var res = dealDamage()
		activate(res)

func onPrepare():
	descriptor.activationAni = ActivationAni.Throw
	connectForCombat(Game.combatTimer, "fatigue_start", "onFatigueStarted")

func onDealtDamage(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/CallbacksP.gd").ForPumpkin.onDealtDamage(self, damageRes)

func onFatigueStarted():
	setTexture(glowingTexture)
	giveHeat(heat)
	activate()

func onShopEntered():
	setTexture(normalTexture)
