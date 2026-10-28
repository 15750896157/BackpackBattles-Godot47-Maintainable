extends Node2D

const colors = {
	Item.Affected.Primary: Color(1, 0.969516, 0.219608),
	Item.Affected.Secondary: Color(0.219608, 1, 0.442142),
	Item.Affected.Tertiary: Color(0.949219, 0.413429, 0.771319),
	Item.Affected.Lightning: Color(0.949219, 0.752484, 0.413429)
}

const starTextures = {
	Item.Affected.Primary: preload("res://Interface/AffectsArrowPrimary.png"),
	Item.Affected.Secondary: preload("res://Interface/AffectsArrowSecondary.png"),
	Item.Affected.Tertiary: preload("res://Interface/AffectsArrowTertiary.png"),
	Item.Affected.Lightning: preload("res://Interface/AffectsArrowLightning.png")
}

var poolingHandle
var line
var sortLength
var star

func preset():
	line = $Line2D
	star = $Star

func setPositions(item, end: Vector2):
	return load("res://Runtime/Callbacks/Items/Exclusive/Animations/CallbacksA.gd").ForAffectsLine.setPositions(self, item, end)

func setColor(color: int):
	modulate = colors[color]
	star.texture = starTextures[color]

func getLength() -> float:
	return sortLength

func moveBy(vec: Vector2):
	position += vec
