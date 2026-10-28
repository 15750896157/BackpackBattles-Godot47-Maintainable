extends Node2D

const healthLostParticles = preload("res://Interface/Combat/HealthLostParticles.tscn")
const barWidth = 216

@onready var bar = $Bar
@onready var healthbarMat = bar.material
@onready var label = $Label
@onready var tween = $Tween
@onready var character = get_parent().get_parent()
var lastRelHealth = 1.0
var updateQueued = false

func _ready() -> void :
	load("res://Runtime/Behavior/Features/Interface/HealthbarBehavior.gd")._ready(self)

func ready_deferred():
	updateNumber()

func onHealthChanged(_damageResult = null):
	if not updateQueued:
		updateQueued = true
		call_deferred("updateBar")

func updateBar():
	return load("res://Runtime/Behavior/Features/Interface/HealthbarBehavior.gd").updateBar(self)

func updateNumber():
	label.text = str(roundi(character.curHealth)) + "/" + str(roundi(character.getMaxHealth()))
