extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageMeter/DamageMeter.gd")

static func updateMetricList(subject: Receiver):
	subject.metricList.clearList()

	var nonStackMetrics = subject.metricIndicesReversed[Game.ItemMetrics.Block]
	for i in subject.metricIndices.size():
		var index = subject.metricIndices[i]

		if i < nonStackMetrics:
			subject.metricList.addItem(subject.metricKeys[index])
		else:

			var keyword = Game.typeToKeyword(subject.stacksMetricOffset + i)

			subject.metricList.addItem(keyword + "_NAME", Util.getIconTexture(keyword))

	subject.metricList.selectItemByIndex(subject.metricIndicesReversed[subject.visibleMetric])

static func updatePlot(subject: Receiver):
	var metrics = subject.getSubMetrics()
	for i in metrics.size():
		var metric = metrics[i]
		var plot = ObjectPool.instantiate(subject.plotScene)
		subject.vboxContainer.add_child(plot)
		var playerId = 0 if subject.player else 1
		plot.setStatLogger(Game.combatLog.statLoggers[playerId])
		plot.setMetric(metric)
		subject.plots.push_back(plot)

static func getSubMetrics(subject: Receiver):
	var metrics = []
	if subject.visibleMetric >= Game.ItemMetrics.Block:
		if subject.player:
			for changeType in [Item.StackChangeType.Added_Player,
										Item.StackChangeType.Removed_Player,
										Item.StackChangeType.Used_Player]:
				metrics.push_back(Item.getStackMetricIndex(changeType, subject.metricToEventType(subject.visibleMetric)))
		else:
			for changeType in [Item.StackChangeType.Added_Opponent,
										Item.StackChangeType.Removed_Opponent,
										Item.StackChangeType.Used_Opponent]:
				metrics.push_back(Item.getStackMetricIndex(changeType, subject.metricToEventType(subject.visibleMetric)))

	elif subject.visibleMetric >= Game.ItemMetrics.Stamina:
		for changeType in [Item.StackChangeType.Used_Player,
									Item.StackChangeType.Added_Player,
									Item.StackChangeType.Removed_Opponent]:
			metrics.push_back(Item.getMultiMetricIndex(changeType, subject.visibleMetric))

	else:
		metrics.push_back(subject.visibleMetric)

	if subject.visibleMetric == Game.ItemMetrics.Damage:
		metrics.push_back(Game.ItemMetrics.Misses)
		metrics.push_back(Game.ItemMetrics.DamageBlocked)

	elif subject.visibleMetric == Game.ItemMetrics.Heal:
		metrics.push_back(Game.ItemMetrics.Overheal)
		metrics.push_back(Game.ItemMetrics.MaxHealth)

	elif subject.visibleMetric == Game.ItemMetrics.Activations:
		metrics.push_back(Game.ItemMetrics.OutOfStamina)

	return metrics

static func updateMeter(subject: Receiver, event, statLogger: CombatStatLogger):
	if event == null:
		return

	subject.currentEvent = event

	if not subject.isVisible():
		return

	subject.clear()

	var metrics = subject.getSubMetrics()

	for i in metrics.size():
		var metric = metrics[i]
		var dict = statLogger.getValuesForMetricAt(metric, event.id)

		var plot = null
		if subject.plots.size() > i:
			plot = subject.plots[i]

		var addMetric: bool = (plot != null and plot.visible) or not dict.is_empty()

		if addMetric:
			if metrics.size() > 1:
				var label = subject.stackChangeSectionLabel.instantiate()
				subject.vboxContainer.add_child(label)

				if subject.visibleMetric == Game.ItemMetrics.Stamina:
					label.translationKey = subject.submetricNames_stamina[i]

				elif metric in subject.metricKeys:
					label.translationKey = subject.metricKeys[metric]
				else:
					var isBuff = Game.isBuff(subject.metricToEventType(subject.visibleMetric))
					if isBuff:
						label.translationKey = subject.submetricNames_buff[i]
					else:
						label.translationKey = subject.submetricNames_debuff[i]

				label.updateLocale()

			if not dict.is_empty():
				subject.addMeter(dict, event.timestamp, plot)

			if plot != null:
				plot.get_parent().move_child(plot, -1)

			subject.setTime(event.timestamp)

static func addMeter(subject: Receiver, dmgMeter: Dictionary, combatTime: float, plot):

	var totalDamage = 0.0
	for source in dmgMeter:
		totalDamage += dmgMeter[source]

	var sortedEntries: Array = Util.sortDict(dmgMeter)
	var largestDmg = float(dmgMeter[sortedEntries[0]])

	for source in sortedEntries:
		var entry = ObjectPool.instantiate(subject.damageMeterEntry)
		subject.vboxContainer.add_child(entry)

		var dmg = dmgMeter[source]
		var relDmg = dmg / totalDamage if totalDamage > 0 else 0
		var dps = dmg / max(0.5, combatTime)
		var relToLargest = dmg / largestDmg if largestDmg > 0 else 0

		entry.init(subject.player, source, dmg, dps, relDmg, relToLargest, plot, subject)
		if plot != null:
			Util.dictAppend(subject.plotToEntry, plot, entry)

		Util.dictAppend(subject.itemToEntry, source, entry)

	if sortedEntries.size() > 1:
		var totalEntry = ObjectPool.instantiate(subject.totalScene)
		subject.vboxContainer.add_child(totalEntry)
		totalEntry.init(totalDamage, totalDamage / max(0.5, combatTime))

static func close(subject: Receiver):
	subject.isOpen = false
	subject.metricList.hide()
	subject.scrollContainer.hide()
	subject.scrollContainer.onClose()
	subject.icon.show()
	subject.vResizeButton.hide()

	if subject.player:
		subject.offset_left = 0
		subject.openButton.flip_h = true
	else:
		subject.offset_right = 62
		subject.openButton.flip_h = false

	subject.openButton.size = Vector2(63, 103)
	subject.custom_minimum_size.y = 115
	subject.offset_bottom = 0

static func onMetricSelected(subject: Receiver, index, text):
	var asMetric = subject.metricIndices[index]
	if asMetric == subject.visibleMetric: return

	subject.visibleMetric = asMetric
	subject.clearPlots()
	if Game.combatLog.loggingFinished:
		subject.updatePlot()

	var playerId = 0 if subject.player else 1
	subject.updateMeter(subject.currentEvent, Game.combatLog.statLoggers[playerId])
