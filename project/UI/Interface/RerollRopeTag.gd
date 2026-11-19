extends Node2D

@onready var sprite = $Tag
@onready var label = $Cost
@onready var animation = $Cost/AnimationPlayer

const tagTextures = [
	preload("res://Art/Assets/Shop/RerollRopeLabel1.png"),
	preload("res://Art/Assets/Shop/RerollRopeLabel3.png"),
	preload("res://Art/Assets/Shop/RerollRopeLabel3.png")
]

func getColor(cost):
	return load("res://Code/Runtime/Callbacks/Interface/CallbacksR.gd").ForRerollRopeTag.getColor(self, cost)

func onGoldChanged():
	var cost = Game.shopSceneNode.getRerollCost()
	var color = getColor(cost)

	label.set("theme_override_colors/font_color", color)

func onCostChanged(cost, increased):
	label.set("theme_override_colors/font_color", getColor(cost))
	label.text = str(cost)
	sprite.texture = tagTextures[clampi(cost - 1, 0, tagTextures.size() - 1)]
	sprite.material.set_shader_parameter("progress", 0.0)
	sprite.material.set_shader_parameter("overlayTexture", tagTextures[clampi(cost, 0, tagTextures.size() - 1)])
	animation.play("RESET")
	if increased:
		animation.play("PriceChanged")
