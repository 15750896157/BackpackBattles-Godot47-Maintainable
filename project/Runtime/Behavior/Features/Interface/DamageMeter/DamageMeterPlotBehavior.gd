extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageMeter/DamageMeterPlot.gd")

static func preset(subject: Receiver):
	subject.linesNode = subject.get_node("Lines")
	subject.coordinateSystem = subject.get_node("Panel")
	subject.timeZeroLabel = subject.get_node("Time1")
	subject.combatDurationLabel = subject.get_node("Time2")
	subject.maxValueLabel = subject.get_node("Node2D/Max")
	subject.hoveredTimeLine = subject.get_node("HoveredTime")

	subject.add_to_group("Localized")
	Util.localizeFonts(subject)

static func updateLocale(subject: Receiver):
	subject.timeZeroLabel.text = "0.0" + Util.tra("FORMAT_Second")
	var totalTime = Game.combatLog.getCombatDuration()
	subject.combatDurationLabel.text = ("%1.2f" % totalTime) + Util.tra("FORMAT_Second")

static func setHoveredTime(subject: Receiver, time: float):
	var totalTime = Game.combatLog.getCombatDuration()
	var xScale = subject.coordinateSystem.size.x / totalTime
	Util.killTween(subject.timeTween)
	subject.timeTween = subject.create_tween()
	subject.timeTween.tween_property(subject.hoveredTimeLine, "position:x",
		subject.coordinateSystem.position.x + time * xScale, 0.1)
