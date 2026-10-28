extends Cube

@onready var spikes = int(getP("spikes"))

func canAffect(item):
	return item.hasCooldown()

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPlasticCube.doCooldownEffect(self)

