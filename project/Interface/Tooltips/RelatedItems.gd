extends "res://Interface/Tooltips/TooltipItemLayout.gd"

@onready var header = $RelatedHeader

var maxWidth = 420

func setItem(item, tooltip):
	return load("res://Runtime/Callbacks/Interface/Tooltips/CallbacksR.gd").ForRelatedItems.setItem(self, item, tooltip)

