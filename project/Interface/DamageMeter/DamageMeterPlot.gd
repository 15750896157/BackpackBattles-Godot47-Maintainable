extends Control
class_name DamageMeterPlot

const lineScene = preload("res://Interface/DamageMeter/PlotLine.tscn")

const colors = [
	Color(0.996094, 0.47081, 0.47081),
	Color(0.96875, 0.682571, 0.363281),
	Color(0.986328, 0.887328, 0.435371),
	Color(0.704778, 0.988281, 0.602234),
	Color(0.389587, 0.958984, 0.71877),
	Color(0.024536, 0.785156, 0.776243),
	Color(0.51059, 0.815988, 0.990234),
	Color(0.511657, 0.507812, 1),
	Color(0.811584, 0.507812, 1),
	Color(0.955731, 0.561882, 0.978516),
	Color(1, 0.535156, 0.73671)
]

var linesNode
var coordinateSystem
var timeZeroLabel
var combatDurationLabel
var maxValueLabel
var hoveredTimeLine

var poolingHandle
var statLogger: CombatStatLogger

var sourceSorting: Dictionary
var lines: Dictionary
var timeTween: Tween

func preset():
	return load("res://Runtime/Behavior/Features/Interface/DamageMeter/DamageMeterPlotBehavior.gd").preset(self)

func returnToObjectPool():
	for line in linesNode.get_children():
		line.returnToObjectPool()

	lines.clear()

	ObjectPool.returnInstance(self)

func setStatLogger(_statLogger: CombatStatLogger):
	statLogger = _statLogger

func setMetric(metric):
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterPlotBehavior.gd").setMetric(self, metric)

func updateLocale():
	return load("res://Runtime/Behavior/Features/Interface/DamageMeter/DamageMeterPlotBehavior.gd").updateLocale(self)

func setHoveredTime(time: float):
	return load("res://Runtime/Behavior/Features/Interface/DamageMeter/DamageMeterPlotBehavior.gd").setHoveredTime(self, time)

func showLine(source):
	lines[source].show()

func hideLine(source):
	lines[source].hide()

func getColor(source) -> Color:
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterPlotBehavior.gd").getColor(self, source)

func getSymbol(source) -> Texture2D:
	var index = sourceSorting[source]
	var wrappedIndex = index % symbols.size()
	return symbols[wrappedIndex]

func isActive(source) -> bool:
	return lines[source].visible

const symbols = [
	preload("res://Interface/DamageMeter/Plot/Symbol_Star.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Triangle.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Circle.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Square.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Moon.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Heart.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Cross.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Tear.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Cloud.png"),
	preload("res://Interface/DamageMeter/Plot/Symbol_Pacman.png"),
]
