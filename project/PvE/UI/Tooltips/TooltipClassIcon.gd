extends Control

var poolingHandle
var sprite

func preset():
	sprite = $Sprite2D

func setClass(classI):
	if classI == - 1:
		sprite.texture = Game.neutralClassIcon
	else:
		sprite.texture = Game.classIcons[classI]
