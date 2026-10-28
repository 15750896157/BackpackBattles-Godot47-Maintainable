extends Item

const amuletColor = Color(0.580392, 0.266667, 0.960784)
var activationParticles = load("res://Items/Exclusive/Particles/AmuletofDarknessParticles.tscn")

@onready var damageThreshold = int(getP("damt"))
var damageAcc: int

func _ready():
	super._ready()
	damageSource = DamageSource.new().setItem(self)
	specificDragParticles[0].self_modulate = amuletColor

func canAffect(item):
	return item.canActivate()

func onPrepare():
	damageAcc = 0
	connectForCombat(opponent(), "character_attacked", "onOpponentDamaged")

	for item in getAffectedItems():
		connectForCombat(item, "activated", "onItemActivated")

func onItemActivated(event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAmuletofDarkness.onItemActivated(self, event)

func onOpponentDamaged(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksA.gd").ForAmuletofDarkness.onOpponentDamaged(self, damageRes)

