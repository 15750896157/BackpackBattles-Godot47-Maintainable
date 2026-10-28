extends Node2D

enum ChangeType{
	Gain = 0,
	Resisted = 1,
	Protected = 2,
	Reflected = 3
}

const positiveColor = Color(0.590118, 1, 0.566406)
const negativeColor = Color(1, 0.566406, 0.566406)
const labelFormat = "[center][color=#{color}]{text}"
const buffFormat = "[center][color=#{color}]{changeType}{amount}{icon}"
const g = 100.0

var white_html = Color.WHITE.to_html()
var positiveColor_html = positiveColor.to_html()
var negativeColor_html = negativeColor.to_html()

var label
var animation
var linear_velocity = Vector2()
var gravity_scale = 0.0

func preset():
	animation = $AnimationPlayer
	label = $Label

func _physics_process(delta):
	linear_velocity.y += g * delta * gravity_scale
	position += linear_velocity * delta

func spawnLabel(type, amount = 0, changeType = ChangeType.Gain, appliedToOpponent = null):
	return load("res://Runtime/Behavior/Interface/DamageNumbers/BuffLabelBehavior.gd").spawnLabel(self, type, amount, changeType, appliedToOpponent)

func spawnLabelOnItem(type: int, amount):
	return load("res://Runtime/Behavior/Interface/DamageNumbers/BuffLabelBehavior.gd").spawnLabelOnItem(self, type, amount)

func spawnStatLabelOnItem(stat: int, amount, onOpponent):
	return load("res://Runtime/Behavior/Interface/DamageNumbers/BuffLabelBehavior.gd").spawnStatLabelOnItem(self, stat, amount, onOpponent)

func delete():
	animation.stop()
	ObjectPool.returnInstance(self, Util.BUFFLABEL_SCENE)
