extends ColorRect

@onready var UI = get_parent()

func _unhandled_input(event: InputEvent) -> void :
	if (visible and
		UI.visible and
		not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) and
		not (event is InputEventMouseMotion) and
		not event is InputEventKey):

		get_viewport().set_input_as_handled()
