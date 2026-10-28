extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/CombatStatLogger.gd")

static func clear(subject: Receiver):
	for history in subject.characterStatHistories.values():
		history.clear()

	for stackHistory in subject.stackHistories.values():
		stackHistory.clear()

	for i in subject.metricHistories.size():
		for history in subject.metricHistories[i].values():
			history.clear()

	subject.itemTooltipHistories.clear()
	subject.itemMetricHistories.clear()
	subject.itemStateHistories.clear()

static func prepareItem(subject: Receiver, item):
	var arr = []
	for metric in Item.getNumItemMetrics():
		var statHistory = StatHistory.new()
		statHistory.addValue( - 1, item.getMetric(metric))
		arr.push_back(statHistory)
	subject.itemMetricHistories[item] = arr

	if item.character().playerId == subject.playerId:
		var arr2 = []
		for stat in Item.getNumTooltipStats():
			var statHistory = StatHistory.new()
			statHistory.addValue( - 1, item.getStat(stat))
			arr2.push_back(statHistory)
		subject.itemTooltipHistories[item] = arr2

		subject.itemStateHistories[item] = StatHistory.new()

static func getStatHistoriesForMetric(subject: Receiver, metric: int) -> Dictionary:
	var dict = {}
	for type in subject.metricHistories[metric]:
		var statHistory = subject.metricHistories[metric][type]
		if statHistory.hasData():
			dict[type] = statHistory
	for item in subject.itemMetricHistories:
		var statHistory = subject.itemMetricHistories[item][metric]
		if statHistory.hasData():
			dict[item] = statHistory
	return dict

static func printItemHistories(subject: Receiver):
	for item in subject.itemMetricHistories:
		for statType in subject.itemMetricHistories[item].size():
			var statHistory = subject.itemMetricHistories[item][statType]
			if statHistory.values.size() > 1:
				print(item.getName(), " stat ", statType, " = ", statHistory.values)

static func getValuesForMetricAt(subject: Receiver, metric: int, eventNum: int) -> Dictionary:
	var dict = {}
	for type in subject.metricHistories[metric]:
		var val = subject.getMetricAt(metric, type, eventNum)
		if val > 0: dict[type] = val
	for item in subject.itemMetricHistories:
		var val = subject.getItemMetricAt(item, metric, eventNum)
		if val > 0:
			dict[item] = val
	return dict
