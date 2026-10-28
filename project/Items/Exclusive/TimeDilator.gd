extends Item

var timeDilatorAni = load("res://Items/Animations/TimeDilatorAni.tscn")
const timeDilatorSound = preload("res://Assets/Sound/Tick2.wav")

@onready var slow = getP("slow") / 100.0
@onready var speedUp = getP("speed") / 100.0

var tickI: int

func onPrepare():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForTimeDilator.onPrepare(self)

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksT.gd").ForTimeDilator.doCooldownEffect(self)

func playActivationSound():
	var pitch = 1.0 if tickI % 2 == 0 else 0.7
	Sound.playSound(timeDilatorSound, 5, pitch)
