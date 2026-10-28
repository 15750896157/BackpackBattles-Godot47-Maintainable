extends PullButton

const arrow = preload("res://Interface/ArrowButton2.png")
const arrow_hovered = preload("res://Interface/ArrowButton2_hovered.png")
const windParticles = preload("res://Interface/WindParticles.tscn")
const windSound = preload("res://Assets/Sound/Swoosh1.wav")

@onready var hint = get_parent().get_node("PushToStorageHint")
var particleReadyTime = 0.0

var pullTween: Tween

func _ready():
	super._ready()
	connect("mouse_entered", Callable(self, "onHover"))
	connect("mouse_exited", Callable(self, "onHoverEnd"))

func _unhandled_input(event):
	load("res://Runtime/Callbacks/Interface/CallbacksP.gd").ForPushToStorageButton._unhandled_input(self, event)

func _button_down():
	if not Game.draggedItem:
		Game.cancelSwitch()
	super._button_down()

func tweenFinished():
	setDisabled(false)
	progress = 1
	set_physics_process(true)

func setDisabled(_disabled):
	disabled = _disabled

func onHover():
	if not Game.draggedItem:
		super.onHover()
		hint.show()
		self.icon = arrow_hovered

func onHoverEnd():
	super.onHoverEnd()
	hint.hide()
	self.icon = arrow

func trigger():
	return load("res://Runtime/Callbacks/Interface/CallbacksP.gd").ForPushToStorageButton.trigger(self)

