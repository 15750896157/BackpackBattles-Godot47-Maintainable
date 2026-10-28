extends LocalizedControl
class_name FocusGrabbingControl

@export var localized = true
@export var playClickSound = true
@export var releaseFocus = true
@onready var me = self

func _ready() -> void :
	super._ready()

	Util.tryConnect(self, "mouse_entered", self, "onHover")
	if releaseFocus:
		Util.tryConnect(self, "mouse_exited", self, "onHoverEnd")
	if has_signal("pressed") and playClickSound:
		Util.tryConnect(self, "pressed", self, "onPressed")

func updateLocale():
	if localized:
		super.updateLocale()

func onHover():
	Util.grabFocus(self)
	Game.onHoverInteractable(self)

func onHoverEnd():
	Util.releaseFocus(self)
	Game.onHoverInteractableEnd(self)

func onPressed():
	Game.onClickButton()

func enable():
	return load("res://Runtime/Callbacks/Interface/CallbacksF.gd").ForFocusGrabbingControl.enable(self)

func disable():
	return load("res://Runtime/Callbacks/Interface/CallbacksF.gd").ForFocusGrabbingControl.disable(self)

