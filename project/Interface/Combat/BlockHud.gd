extends Node2D

const scaleCurve = preload("res://Interface/Combat/BlockShieldScale.tres")
const tooltipScene = preload("res://Interface/Tooltips/SimpleTooltip.tscn")

@export var keyword: String
@export var scaleThreshold = 50

@onready var character = get_parent()
@onready var tween = $Tween
@onready var label = $Label
@onready var sprite = $Sprite2D
@onready var baseScale = sprite.scale
@onready var animation = $AnimationPlayer
var tooltip
var prevValue
var pve_high_contrast = false
var pve_label_defaults: Dictionary = {}
var pve_timeline_status: Dictionary = {}

func _ready() -> void :
	load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd")._ready(self)

func _pve_update_locale_when_ready():
	return await load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd")._pve_update_locale_when_ready(self)

func pve_update_accessibility(enabled: bool):
	return load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd").pve_update_accessibility(self, enabled)

func _draw():
	return load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd")._draw(self)

func updateLocale():
	return load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd").updateLocale(self)

func pve_set_timeline_status(state: Dictionary):
	if pve_timeline_status == state: return
	pve_timeline_status = state.duplicate(true)
	if is_instance_valid(tooltip) and tooltip.visible: updateLocale()

func calcScale(value) -> float:
	return load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd").calcScale(self, value)

func updateHud(value):
	return load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd").updateHud(self, value)

func onHover():
	return load("res://Runtime/Behavior/Features/Interface/Combat/BlockHudBehavior.gd").onHover(self)

func onHoverEnd():
	if tooltip.visible:
		Game.onHoverInteractableEnd(self)
		hideTooltip()

func onLeaveCombat():
	pve_timeline_status.clear()
	hideTooltip()

func hideTooltip():
	tooltip.hide()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(tooltip):
			tooltip.discard()
