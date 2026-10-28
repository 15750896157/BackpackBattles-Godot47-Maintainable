extends Node2D

@onready var bars = $HBoxContainer.get_children()

const ANI_DUR = 0.5

var alphaTween

func _ready():
	reset()
	Game.connect("shop_opened", Callable(self, "onShopOpened"))
	Game.connect("fresh_run_started", Callable(self, "reset"))

func reset():
	for bar in bars:
		bar.self_modulate.a = 0
		bar.scale.y = 0
		bar.custom_minimum_size.y = 0

func onShopOpened():
	return load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForShopRarityChart.onShopOpened(self)

func appear():
	alphaTween = Util.refreshTween(alphaTween)
	alphaTween.tween_property(self, "modulate:a", 1.0, 0.2)

func disappear():
	alphaTween = Util.refreshTween(alphaTween)
	alphaTween.tween_property(self, "modulate:a", 0.0, 0.2)
