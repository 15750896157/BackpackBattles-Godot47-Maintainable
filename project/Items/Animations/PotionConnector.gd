extends Sprite2D

@onready var animation = $AnimationPlayer
@onready var potion = get_parent()

@onready var startScale = scale

var active = false
var visuallyActive = false

func _ready() -> void :
	modulate.g = Util.rng.randf_range(0.9, 1.1)
	set_as_top_level(true)

func checkState():
	if visuallyActive and not active:
		animation.play("Disappear")
	elif not visuallyActive and active:
		animation.play("Appear")

	visuallyActive = active

func appear():
	active = true

func _physics_process(_delta: float) -> void :
	load("res://Runtime/Callbacks/Items/Animations/CallbacksP.gd").ForPotionConnector._physics_process(self, _delta)

func disappear():
	active = false

func reset():
	animation.stop()
	hide()
	active = false
	visuallyActive = false
