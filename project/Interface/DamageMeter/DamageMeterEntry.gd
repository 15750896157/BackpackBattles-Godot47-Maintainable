extends FocusGrabbingControl

const stylebox_normal = preload("res://Interface/DamageMeter/DamageMeterEntryStylebox.tres")
const stylebox_connected = preload("res://Interface/DamageMeter/DamageMeterEntryStylebox_connected.tres")
const defaultColorProp: = "theme_override_colors/default_color"
const fontColorProp = "theme_override_colors/font_color"
const textActiveColor: = Color(1, 0.92549, 0.831373)
const textInactiveColor: = Color(0.697266, 0.684629, 0.668667)

var nameLabel
var progressBar
var relDamageLabel
var absDamageLabel
var panel
var plotButton
var progressBarStylebox: StyleBoxFlat
var player
var source
var absDamage
var dps
var plot = null
var damageMeter

var plotButtonActiveColor: Color
const plotButtonInactiveColor: = Color(0.652344, 0.606742, 0.549141)
var plotButtonActive: bool

func preset():
	return load("res://Runtime/Behavior/Features/Interface/DamageMeter/DamageMeterEntryBehavior.gd").preset(self)

func init(_player: bool, _source, _absValue, _dps: float,
	relValue: float, relToLargest: float, _plot, _damageMeter):
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterEntryBehavior.gd").init(self, _player, _source, _absValue, _dps, relValue, relToLargest, _plot, _damageMeter)

func updateLocale():
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterEntryBehavior.gd").updateLocale(self)

func highlight():
	panel.set("theme_override_styles/panel", stylebox_connected)

func unhighlight():
	panel.set("theme_override_styles/panel", stylebox_normal)

func onHover():
	super.onHover()
	if typeof(source) == TYPE_INT:

		Game.combatLog.highlightSource(source, player)
	else:
		Game.combatLog.highlightItem(source)

func onHoverEnd():
	super.onHoverEnd()
	Game.combatLog.unhighlightItem()

func setPlotButtonStyle(color: Color, symbol: Texture2D, active: bool = true):
	plotButton.texture = symbol
	plotButtonActiveColor = color
	plotButtonActive = active

	if active:
		onShowPlotLine()
	else:
		onHidePlotLine()

func onPlotButtonToggled():
	setPlotButtonActive( not plotButtonActive)

func setPlotButtonActive(active):
	plotButtonActive = active

	if plotButtonActive:
		plot.showLine(source)
		onShowPlotLine()
	else:
		plot.hideLine(source)
		onHidePlotLine()

func onShowPlotLine():
	return load("res://Runtime/Behavior/Features/Interface/DamageMeter/DamageMeterEntryBehavior.gd").onShowPlotLine(self)

func onHidePlotLine():
	return load("res://Runtime/Behavior/Features/Interface/DamageMeter/DamageMeterEntryBehavior.gd").onHidePlotLine(self)

func _gui_input(event):
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterEntryBehavior.gd")._gui_input(self, event)

