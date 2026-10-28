extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageMeter/DamageMeterPlot.gd")

static func setMetric(subject: Receiver, metric):
	for line in subject.linesNode.get_children():
		line.returnToObjectPool()

	var statHistories = subject.statLogger.getStatHistoriesForMetric(metric)
	if statHistories.is_empty():
		subject.hide()
		return

	var maxValue = 0
	var endValues = Dictionary()

	for source in statHistories:
		var statHistory: StatHistory = statHistories[source]

		var value = statHistory.getValueAt(Game.combatLog.getLastEventNum())
		endValues[source] = value
		maxValue = max(value, maxValue)

	if maxValue == 0:
		print("plot maxvalue == 0")
		subject.hide()
		return

	subject.show()
	subject.maxValueLabel.text = str(snapped(maxValue, 0.1))
	subject.sourceSorting.clear()
	var sortedSources: Array = Util.sortDict(endValues)
	for i in sortedSources.size():
		subject.sourceSorting[sortedSources[i]] = i

	var totalTime = Game.combatLog.getCombatDuration()

	var xScale = subject.coordinateSystem.size.x / totalTime
	var yScale = subject.coordinateSystem.size.y / maxValue

	subject.updateLocale()

	for source in statHistories:
		var line: PlotLine = ObjectPool.instantiate(subject.lineScene)

		subject.lines[source] = line
		subject.linesNode.add_child(line)
		line.setColor(subject.getColor(source))
		line.setSymbol(subject.getSymbol(source))
		var statHistory: StatHistory = statHistories[source]
		for eventNum in statHistory.eventNumbers:
			if eventNum < Game.combatLog.getNumEvents():
				var value = statHistory.getValueAt(eventNum)
				var time: float
				if eventNum == - 1:
					time = 0.0
				else:
					time = Game.combatLog.getTimeOfEvent(eventNum)

				line.addPoint(Vector2(time * xScale, value * yScale))
		line.flatline(subject.coordinateSystem.size.x)

static func getColor(subject: Receiver, source) -> Color:
	var index = subject.sourceSorting[source]
	var wrappedIndex = index % subject.colors.size()
	var iteration = index / subject.colors.size()
	if iteration == 0:
		return subject.colors[wrappedIndex]
	elif iteration == 1:
		return subject.colors[wrappedIndex].lightened(0.5)
	else:
		return subject.colors[wrappedIndex].darkened(0.3)
