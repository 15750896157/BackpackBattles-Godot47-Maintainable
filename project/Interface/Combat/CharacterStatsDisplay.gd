extends Node2D

const ICONS_PER_COLUMN = 6
const TOTAL_ICON_SIZE = Vector2(60, 60)
const iconScene = preload("res://Interface/Combat/CharacterStatIcon.tscn")

var icons = {}

var activeIcons = []
var positionTween = null

@onready var isPlayer = (get_parent().get_parent().playerId == Character.ID.PLAYER)

func _ready():
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatsDisplayBehavior.gd")._ready(self)

func onStatChanged(stat: int, value):
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatsDisplayBehavior.gd").onStatChanged(self, stat, value)

func activateIcons():
	for icon in activeIcons:
		icon.appear()

func repositionIcons(fromIndex: int):
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatsDisplayBehavior.gd").repositionIcons(self, fromIndex)

func getGridPosition(iconIndex: int) -> Vector2:
	var column = iconIndex / ICONS_PER_COLUMN
	var row = iconIndex % ICONS_PER_COLUMN
	if isPlayer:
		column *= - 1
	return Vector2(column, row) * TOTAL_ICON_SIZE

func reset():
	Util.killTween(positionTween)
	positionTween = null
	for icon in activeIcons:
		icon.disappear()
	activeIcons.clear()

func _physics_process(delta):
	if Util.isTweenRunning(positionTween):
		positionTween.set_speed_scale(1)
		positionTween.custom_step(1 / 60.0)
		positionTween.set_speed_scale(0)
