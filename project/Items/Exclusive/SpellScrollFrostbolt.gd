extends Item

@onready var coldAmount = int(getP3())

var maxUses: int
var uses: int

func _ready() -> void :
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func canAffect(item):
	return item.hasType(Type.Ice) and not item.isA(descriptor)

func onPrepare():
	uses = 0
	maxUses = int(getP1()) + getNumAffectedItems()

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForSpellScrollFrostbolt.doCooldownEffect(self)

