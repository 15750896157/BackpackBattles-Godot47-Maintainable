extends Sprite2D

@onready var trophy = $Trophy
@onready var trail = $Trophy/Trail
@onready var animation = $AnimationPlayer
@onready var trailParticles = $Trophy/TrailParticles

const moveSound = preload("res://Assets/Sound/Swoosh3.wav")
const arriveSound = preload("res://Assets/Sound/Bell2.mp3")
const popinSound = preload("res://Assets/Sound/Bell2.mp3")

func setEmpty():
	trophy.position = Vector2.ZERO
	animation.play("RESET")
	animation.advance(1)

func setFull():
	trophy.position = Vector2.ZERO
	trophy.scale = Vector2(0.9, 0.9)

func popIn():
	trophy.position = Vector2.ZERO
	animation.play("Popin")
	Sound.playSound(popinSound)

func moveToPos(pos: Vector2):
	return load("res://Runtime/Callbacks/Interface/CallbacksT.gd").ForTrophy.moveToPos(self, pos)
