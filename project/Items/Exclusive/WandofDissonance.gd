extends Item

@onready var healthUsed = int(getP("healtht"))
@onready var effectDmg = getP("dam") / 100.0

@onready var availableBuffs = {
	Game.EventType.Mana: int(getP("mana")),
	Game.EventType.Lucky: int(getP("luck")),
	Game.EventType.Regeneration: int(getP("regen"))
}

func _ready():
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksW.gd").ForWandofDissonance.doCooldownEffect(self)

func canAffect(item):
	return item.hasType(Type.Dark)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksW.gd").ForWandofDissonance.onPrepare(self)

