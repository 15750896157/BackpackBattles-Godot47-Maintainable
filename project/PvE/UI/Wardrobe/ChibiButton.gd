extends FocusGrabbingTextureButton

func _ready():
	super._ready()
	Game.connect("character_changed", Callable(self, "updateChibiButton"))
	Util.callNextFrame(self, "updateChibiButton")
	Game.connect("chibi_setting_changed", Callable(self, "updateChibiButton"))

func _toggled(button_pressed):
	flip_h = button_pressed
	Game.onClickButton()
	Game.setChibiMode(button_pressed)

func updateChibiButton():
	visible = Game.getShowChibis()
	button_pressed = Game.getChibiMode()
