extends Node2D

@onready var timeLeftLabel = $Open/TimeLeft
@onready var linkButton = $Open/LinkButton
@onready var openButton = $Closed/OpenButton
@onready var closeButton = $Open/CloseButton
@onready var openNode = $Open
@onready var closedNode = $Closed
@onready var sprite = $Open/RangerPlushie
@onready var baseScale = sprite.scale
const hoverScale = Vector2(1.05, 1.05)

func _ready():
	load("res://Runtime/Callbacks/Utility/CallbacksM.gd").ForMerchButton._ready(self)

func open(saveConfig = true):
	openNode.show()
	closedNode.hide()
	if saveConfig:
		Game.setConfigValue("Options", "hide_ranger_plushie", false)

func close(saveConfig = true):
	openNode.hide()
	closedNode.show()
	if saveConfig:
		Game.setConfigValue("Options", "hide_ranger_plushie", true)

func onHover():
	sprite.scale = hoverScale

func onHoverEnd():
	sprite.scale = baseScale
