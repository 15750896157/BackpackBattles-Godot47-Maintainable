extends Item

const explosionSound = preload("res://Assets/Sound/Explosion1.wav")

@onready var activationParticles = $ActivationParticles
@onready var damFactor = getP("dam")

func _ready() -> void :
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBomb.doCooldownEffect(self)

