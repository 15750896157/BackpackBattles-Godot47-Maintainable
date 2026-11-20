extends Node

var defaultInputMappings = Dictionary()

func _ready():
	load("res://Code/Runtime/Callbacks/Interface/Options/CallbacksI.gd").ForInputMapping._ready(self)

