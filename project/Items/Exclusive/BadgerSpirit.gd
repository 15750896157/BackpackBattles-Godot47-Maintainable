extends SpiritCompanion

const pickupSound = preload("res://Assets/Sound/Badger1.ogg")
const dropSound = preload("res://Assets/Sound/Badger2.ogg")

@onready var healthThreshold = getP("healtht") / 100.0
@onready var manaNeeded = int(getP("manat"))
var activated: bool

func canAffect(item):
	return item.hasType(Type.Nature)

func onPrepare():
	activated = false
	connectForCombat(character(), "character_damaged", "onDamaged")

func onDamaged(_healthChange, event):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBadgerSpirit.onDamaged(self, _healthChange, event)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBadgerSpirit.doCooldownEffect(self)

func playPickupSound():
	Sound.playSound_process(pickupSound, - 12, Util.randPitch(0.1))

func playDropSound(volume = 0):
	volume += impactSoundVolume
	Sound.playSound(dropSound, volume - 6, Util.randPitch(0.1))
