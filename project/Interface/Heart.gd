extends Sprite2D

@onready var animation = $AnimationPlayer

const heartRefillParticles = preload("res://Interface/HeartRefillParticles.tscn")
const loseTrySound = preload("res://Assets/Sound/Pop1.wav")
const gainTrySound = preload("res://Assets/Sound/Heal.ogg")

var isFull = true

func setEmpty():
	animation.play("Loss")
	animation.advance(1)
	isFull = false

func loseHeart():
	if isFull:
		animation.play("Loss")
		Sound.playSound(loseTrySound)
		isFull = false

func setFull():
	animation.play("RESET")
	isFull = true

func heal():
	return load("res://Runtime/Callbacks/Interface/CallbacksH.gd").ForHeart.heal(self)

func loseAndHealBack():
	loseHeart()
	Util.callDelayed(self, "heal", 0.5)
