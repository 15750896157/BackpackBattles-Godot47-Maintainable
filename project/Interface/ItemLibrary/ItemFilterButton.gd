extends FocusGrabbingControl

var siblings = []

func _ready() -> void :
	super._ready()
	for node in get_parent().get_children():
		if node != self:
			siblings.push_back(node)

func _toggled(button_pressed: bool) -> void :

	if Game.itemLibrary:
		Game.itemLibrary.filterChanged()

func _gui_input(event):
	if (event is InputEventMouseButton and
		event.button_index == MOUSE_BUTTON_RIGHT and
		not event.pressed):

		toggleGroup()

func isOn() -> bool:
	return self.button_pressed

func onHover():
	super.onHover()

	set("theme_override_colors/font_pressed_color", Util.paramColor)

func onHoverEnd():
	super.onHoverEnd()
	set("theme_override_colors/font_pressed_color", Game.SOFTWHITE)

func toggleGroup():
	return load("res://Runtime/Callbacks/Interface/ItemLibrary/CallbacksI.gd").ForItemFilterButton.toggleGroup(self)

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		set("theme_override_colors/font_pressed_color", Game.SOFTWHITE)
