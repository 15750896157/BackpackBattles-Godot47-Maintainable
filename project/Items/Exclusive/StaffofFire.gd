extends Weapon

@onready var activationParticles = $Icon/ActivationParticles

@onready var manaCost: int = getP1()
@onready var heatCost: int = getP2()
@onready var damBonus: int = getP3()
var numActivations: int

func _ready() -> void :
	super._ready()
	activationParticles.process_material = activationParticles.process_material.duplicate()

func onPrepare():
	numActivations = 0

func onPreDealDamage_early(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForStaffofFire.onPreDealDamage_early(self, damageRes)

func onShopEntered():
	activationParticles.deactivate()
