extends Node2D

var poolingHandle
var sprite
var animation

const zapSize = [
	100.0, 100.0
]

const zapAnis = [
	"Zap",
	"SmallZap"
]

enum ZapStyle{
	Large = 0,
	Small = 1,
}

func preset():
	sprite = $Sprite2D
	animation = $AnimationPlayer

func zap(startPos: Vector2, endPos: Vector2, style: int = ZapStyle.Large):
	return load("res://Runtime/Callbacks/Items/Animations/CallbacksZ.gd").ForZap.zap(self, startPos, endPos, style)

func returnToObjectPool():
	animation.stop()
	ObjectPool.returnInstance(self)
