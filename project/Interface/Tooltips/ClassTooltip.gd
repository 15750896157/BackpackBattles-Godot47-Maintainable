extends "res://Interface/Tooltips/SimpleTooltip.gd"

@onready var subclassesControl = $VBoxContainer/Subclasses

func setParams(header, description):
	subclassesControl.hide()
	Y_BORDER = 120
	super.setParams(Game.getClassName(), Game.getPveClassDescription())
	return
