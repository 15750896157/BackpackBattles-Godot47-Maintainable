extends Node2D

signal finished_loading_materials
var completed: bool = false

const pixel_tex = preload("res://Assets/Pixel.png")

func _ready():
	await load("res://Runtime/Callbacks/Utility/CallbacksM.gd").ForMaterialCompiler._ready(self)

