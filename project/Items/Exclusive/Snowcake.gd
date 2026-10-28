extends Food

@onready var cold = int(getP("cold"))
@onready var coldNeeded = int(getP("coldt"))
@onready var effectDam = getP("damfactor") / 100.0

func _ready():
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSnowcake.doCooldownEffect(self)

