extends Node2D

signal finished_loading_materials
var completed: bool = false

const pixel_tex = preload("res://Art/Assets/Pixel.png")

func _ready():
	await load("res://Code/Runtime/Callbacks/Utility/CallbacksM.gd").ForMaterialCompiler._ready(self)

