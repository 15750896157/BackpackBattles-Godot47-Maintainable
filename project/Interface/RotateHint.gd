extends Node2D

func _ready():
	Util.localizeFonts(self)
	add_to_group("Localized")
	updateLocale()

func _process(delta: float) -> void :
	checkState()
	if visible:
		global_position = get_global_mouse_position()

func checkState():
	if Game.getTotalRotations() > 0:
		queue_free()
	else:
		visible = (Game.draggedItem != null)

func updateLocale():
	return load("res://Runtime/Callbacks/Interface/CallbacksR.gd").ForRotateHint.updateLocale(self)

