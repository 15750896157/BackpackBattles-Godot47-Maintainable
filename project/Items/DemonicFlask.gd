extends Potion

@onready var healthThreshold = getP1() / 100.0 - 0.0001

func _ready() -> void :
	super._ready()
	damageSource = DamageSource.new().setItem(self)

func canDamage() -> bool:
	return true

func onTriggerPotion(triggerEvent = null):
	var dam = opponent().getDebuffStacks()
	dam *= getP2()
	dam = ceil(dam)
	dealEffectDamage(dam, triggerEvent)

func onPrepare():
	connectForCombat(opponent(), "character_damaged", "onDamaged")

func onDamaged(healthChange, event):
	return load("res://Runtime/Callbacks/Items/CallbacksD.gd").ForDemonicFlask.onDamaged(self, healthChange, event)

