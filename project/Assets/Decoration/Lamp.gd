extends Node2D

const sparkScene1 = preload("res://Shader/LampSparkParticles.tscn")
const sparkScene2 = preload("res://Shader/LampSparkParticles2.tscn")
const sparkSound = preload("res://Assets/Sound/Shock1.wav")

const friction = 0.99
const backForce = 7.8
const impulse = 60.0
const offColor = Color(0.929688, 0.849792, 0.905372)

var momentum = 0.0
var broken = false

@onready var light = $ShopLight
@onready var lamp = $Button
@onready var defaultPos = position

func _ready():
	Game.connect("switch_to_shop", Callable(self, "onEnteringShop"))

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Assets/Decoration/LampBehavior.gd")._physics_process(self, delta)

func onLampPressed():
	return load("res://Runtime/Behavior/Features/Assets/Decoration/LampBehavior.gd").onLampPressed(self)

func _gui_input(event):
	return load("res://Runtime/Behavior/Features/Assets/Decoration/LampBehavior.gd")._gui_input(self, event)

func onEnteringShop():
	broken = false
	lamp.enable()
	z_index = 0
	position = defaultPos
	rotation = 0
	momentum = 0
