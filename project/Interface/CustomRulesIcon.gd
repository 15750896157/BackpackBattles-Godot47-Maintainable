extends FocusGrabbingTextureButton

const tooltipScene = preload("res://Interface/Tooltips/CustomRulesTooltip.tscn")

@export var lobbyMode = false

var tooltip = null
var customRules = CustomRules

func onHover():
	super.onHover()
	if isHovered:
		tooltip = tooltipScene.instantiate()
		Game.tooltipsNode.add_child(tooltip)
		tooltip.setRules(customRules, lobbyMode)
		tooltip.forceUpdatePosition(global_position, size)

func onHoverEnd():
	super.onHoverEnd()
	if tooltip != null:
		tooltip.queue_free()
		tooltip = null

func onCustomRulesChanged():
	if tooltip != null:
		tooltip.updateRules(customRules)
		tooltip.forceUpdatePosition(global_position, size)
