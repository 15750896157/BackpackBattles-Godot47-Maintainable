extends Control

const maxSize = Vector2(200, 120)

@onready var label = $Label
@onready var itemNode = $Node2D

var item = null

func setSubclass(descriptor):
	return load("res://Runtime/Callbacks/Interface/Tooltips/CallbacksS.gd").ForSubclassSubtooltip.setSubclass(self, descriptor)

