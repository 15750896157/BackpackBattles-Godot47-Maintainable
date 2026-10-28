extends FocusGrabbingButton

const sound = preload("res://Assets/Sound/Thud3.wav")
const flySound = preload("res://Assets/Sound/Swoosh2.wav")

@onready var animation = $AnimationPlayer
@onready var umbrella = $Umbrella

var state = 0
var broken = false

func _ready():
	super._ready()
	Game.connect("switch_to_shop", Callable(self, "onEnteringShop"))

func _on_UmbrellaBasket_button_down():
	return load("res://Runtime/Behavior/Features/Assets/Decoration/UmbrellaBasketBehavior.gd")._on_UmbrellaBasket_button_down(self)

func _gui_input(event):
	return load("res://Runtime/Behavior/Features/Assets/Decoration/UmbrellaBasketBehavior.gd")._gui_input(self, event)

func onEnteringShop():
	umbrella.z_index = 0
	broken = false
	animation.play("RESET")
	enable()
