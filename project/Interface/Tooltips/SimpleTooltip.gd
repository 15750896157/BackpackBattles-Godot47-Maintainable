extends ToolTip

@onready var descrLabel = $VBoxContainer/Description

func setParams(header, description):
	return load("res://Runtime/Callbacks/Interface/Tooltips/CallbacksS.gd").ForSimpleTooltip.setParams(self, header, description)

