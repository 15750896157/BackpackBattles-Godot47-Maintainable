extends Node2D
class_name NumberLabel

const lifetime = 0.8
const SIZE_CURVE = preload("res://Interface/DamageNumbers/DamageNumberSizeCurve.tres")

var chipDamage: bool = false

var animation
var text
var font

var linear_velocity = Vector2()
var gravity_scale = 0.0
const g = 100.0

func _physics_process(delta):
	linear_velocity.y += g * delta * gravity_scale
	position += linear_velocity * delta

static func isDamageNumber(_type):
	return (_type == Game.EventType.DealDamage or
			_type == Game.EventType.CriticalDamage)

func preset():
	animation = $AnimationPlayer
	text = $Label
	font = text.get("theme_override_fonts/normal_font")

func _ready():
	return load("res://Runtime/Behavior/Features/Interface/DamageNumbers/DamageNumberBehavior.gd")._ready(self)

func spawnNumber(numberType, amount: int):
	return load("res://Runtime/Behavior/Features/Interface/DamageNumbers/DamageNumberBehavior.gd").spawnNumber(self, numberType, amount)

func delete():
	animation.stop()
	ObjectPool.returnInstance(self, Util.NUMBERLABEL_SCENE)
