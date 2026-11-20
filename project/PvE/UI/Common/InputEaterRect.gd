extends Control

func _gui_input(event):
	if visible:
		get_viewport().set_input_as_handled()
