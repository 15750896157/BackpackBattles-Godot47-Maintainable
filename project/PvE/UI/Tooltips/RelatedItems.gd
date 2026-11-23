extends "res://PvE/UI/Tooltips/TooltipItemLayout.gd"

@onready var header = $RelatedHeader

var maxWidth = 420

func setItem(item, tooltip):
	return load("res://Code/Runtime/Callbacks/Interface/Tooltips/CallbacksR.gd").ForRelatedItems.setItem(self, item, tooltip)

