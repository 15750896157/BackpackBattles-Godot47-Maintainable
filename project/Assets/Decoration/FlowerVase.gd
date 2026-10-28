extends FocusGrabbingButton

const sound = preload("res://Assets/Sound/Ceramic1.mp3")
const shatterSound = preload("res://Assets/Sound/JarBreaking.ogg")
const shatterParticles = preload("res://Assets/Decoration/VaseBreakParticles.tscn")

@onready var animation = $AnimationPlayer
@onready var vase = $Vase
@onready var flower = $Vase/Flower

var state = 0
var broken = false

func _ready():
	super._ready()
	Game.connect("switch_to_shop", Callable(self, "onEnteringShop"))

func _on_FlowerVase_button_down():
	return load("res://Runtime/Behavior/Assets/Decoration/FlowerVaseBehavior.gd")._on_FlowerVase_button_down(self)

func _gui_input(event):
	return load("res://Runtime/Behavior/Assets/Decoration/FlowerVaseBehavior.gd")._gui_input(self, event)

func onEnteringShop():
	broken = false
	vase.z_index = - 1
	vase.self_modulate.a = 1.0
	animation.play("RESET")
	enable()
