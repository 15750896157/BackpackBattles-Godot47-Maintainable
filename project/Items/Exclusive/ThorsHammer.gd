extends Weapon

var stunParticles = load("res://Items/Particles/StunParticles.tscn")

@onready var manaNeeded = int(getP("manat"))
@onready var effectDmg = int(getP("dam"))
@onready var blind = int(getP("blind"))

var effectDmgSource: DamageSource

func _ready():
	super._ready()
	effectDmgSource = DamageSource.new().init(self,
		DamageSource.Type.Effect, effectDmg)

func onDealtDamage(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForThorsHammer.onDealtDamage(self, damageRes)

