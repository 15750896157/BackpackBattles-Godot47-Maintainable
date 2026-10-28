extends Item

const pickupSound = preload("res://Assets/Sound/Wolf2.mp3")

var options: Array

func playPickupSound():
	Sound.playSound_process(pickupSound, - 3)

func playDropSound(volume = 0):
	volume += impactSoundVolume
	Sound.playSound(pickupSound, volume - 6)

func canAffect(item):
	return item.hasType(Type.Pet)

func onPrepare():
	addSpeed(getNumAffectedItems() * getP4() / 100.0)
	options = [0, 1, 2]

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksP.gd").ForPowerPuppy.doCooldownEffect(self)

