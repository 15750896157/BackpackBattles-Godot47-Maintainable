extends Card

@onready var fireParticles = $Fire
@onready var damFactor = getP("damfactor") / 100.0
@onready var heat = int(getP2())

func _ready() -> void :
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func doRevealEffect():
	return load("res://Runtime/Callbacks/Items/CallbacksH.gd").ForHoloFireLizard.doRevealEffect(self)

