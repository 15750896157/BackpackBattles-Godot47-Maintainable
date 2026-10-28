extends BaseButton

func _ready() -> void :
	connect("mouse_entered", Callable(self, "onHover"))
	connect("mouse_exited", Callable(self, "onHoverEnd"))
	connect("pressed", Callable(self, "onClicked"))

func onHover():
	modulate = Color(1.3, 1.3, 1.3, 1)
	Game.onHoverInteractableEnd(self)
	Util.grabFocus(self)

func onHoverEnd():
	modulate = Color.WHITE
	Game.onHoverInteractable(self)
	Util.releaseFocus(self)

func onClicked():
	modulate = Color.WHITE
	Game.onClickButton()
