extends Node2D

@onready var sprite = $Sprite2D

func _ready():
	hide()
	Util.callNextFrame(self, "show")

func _process(_delta: float) -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksC.gd").ForCursor._process(self, _delta)

