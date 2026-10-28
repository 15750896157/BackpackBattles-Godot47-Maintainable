extends "res://Interface/CombatLog/CombatLogFilterButton.gd"

@export var hoverPressedStylebox: StyleBox

@onready var normalStylebox = get("theme_override_styles/normal")
@onready var pressedStylebox = get("theme_override_styles/pressed")
@onready var hoverNormalStylebox = get("theme_override_styles/hover")
@onready var normalFontColor = get("theme_override_colors/font_color")
@onready var pressedFontColor = get("theme_override_colors/font_pressed_color")

func _ready():
	super._ready()
	set("theme_override_colors/font_pressed_color", null)
	updateStyleboxes()

func toggle():
	super.toggle()
	updateStyleboxes()

func updateStyleboxes():
	return load("res://Runtime/Callbacks/Interface/CombatLog/CallbacksC.gd").ForCombatLogFilterButtonWithStylebox.updateStyleboxes(self)

