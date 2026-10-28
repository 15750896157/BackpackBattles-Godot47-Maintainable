extends Item

var activationParticles = load("res://Items/Exclusive/Particles/CrowActivationParticles.tscn")
const pickupSound = preload("res://Assets/Sound/Crow1.wav")
const dropSound = preload("res://Assets/Sound/Crow2.wav")

var numActivations: int

@onready var speedBonus = getP("speed") / 100.0
@onready var maxActivations = int(getP("max"))
@onready var luck = int(getP("luck"))

func canAffect(item):
	return item.hasCooldown() or item.inflictsDebuffs()

func onPrepare():
	numActivations = 0

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksC.gd").ForCrow.doCooldownEffect(self)

func playPickupSound():
	Sound.playSound_process(pickupSound, - 4, Util.randPitch(0.1))

func playDropSound(volume = 0):
	volume += impactSoundVolume
	Sound.playSound(dropSound, volume - 4, Util.randPitch(0.1))
