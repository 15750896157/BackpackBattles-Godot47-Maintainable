extends Item

@onready var foodSpeed = getP("speed") / 100.0
@onready var dam = getP("dam")

var affectedFood: Array

func canAffect(item):
	return item.hasType(Type.Food) or item.hasType(Type.Dark)

func onAffectedItemAdded(item, color: int):
	if item.hasType(Type.Food):
		item.addDynamicType(Type.Dark, self)

func onAffectedItemRemoved(item, color: int):
	item.removeDynamicType(Type.Dark, self)

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForCthulhu.onPrepare(self)

func doCooldownEffect():
	stealLife(dam, getP_m("lifesteal") / 100.0)
	activate()
	if not affectedFood.is_empty():
		Util.pickRandomElement(affectedFood).doCooldownEffect()
