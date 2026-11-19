extends FocusGrabbingControl

@export var iconHovered: Texture2D
@onready var iconUnchecked = get("theme_override_icons/radio_unchecked")

func _ready():
	super._ready()
	connect("toggled", Callable(self, "_toggled"))

func onHover():
	super.onHover()
	if not self.button_pressed:
		set("theme_override_icons/radio_unchecked", iconHovered)
	set("theme_override_colors/font_pressed_color", Util.paramColor)

func onHoverEnd():
	super.onHoverEnd()
	if not self.button_pressed:
		setUnchecked()
	set("theme_override_colors/font_pressed_color", Game.SOFTWHITE)

func _toggled(button_pressed):
	if not button_pressed:
		setUnchecked()

func setPressed(isPressed):
	me.set_pressed_no_signal(isPressed)
	if not isPressed:
		setUnchecked()

func setUnchecked():
	set("theme_override_icons/radio_unchecked", iconUnchecked)
