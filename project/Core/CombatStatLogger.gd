extends RefCounted
class_name CombatStatLogger

var playerId: int
var characterStatHistories = {}
var stackHistories = {}
var itemTooltipHistories = {}
var itemMetricHistories = {}
var itemStateHistories = {}
var metricHistories = []

func _init(_playerId = 0):
	playerId = _playerId

	for type in Character.Stat.values():
		characterStatHistories[type] = StatHistory.new()

	for stack in Game.getStacks():
		stackHistories[stack] = StatHistory.new()

	metricHistories.resize(Item.getNumItemMetrics())
	var dict1 = {}
	for type in [Game.EventType.Fatigue, Game.EventType.Poison,
					Game.EventType.Spikes, Game.EventType.Unhealing]:
		dict1[type] = StatHistory.new()

	metricHistories[Game.ItemMetrics.Damage] = dict1

	var dict2 = {}
	var dict3 = {}
	for type in [Game.EventType.Regeneration, Game.EventType.Vampirism]:
		dict2[type] = StatHistory.new()
		dict3[type] = StatHistory.new()

	metricHistories[Game.ItemMetrics.Heal] = dict2
	metricHistories[Game.ItemMetrics.Overheal] = dict3
	for i in range(Game.ItemMetrics.Overheal + 1, metricHistories.size()):
		metricHistories[i] = {}

func clear():
	return load("res://Runtime/Behavior/Core/CombatStatLoggerBehavior.gd").clear(self)

func logCharacterStat(stat: int, eventNum: int, value: float):

	characterStatHistories[stat].addValue(eventNum, value)

func getCharacterStatAt(stackType: int, eventNum: int) -> float:
	return characterStatHistories[stackType].getValueAt(eventNum)

func logStack(stackType: int, eventNum: int, value: int):
	stackHistories[stackType].addValue(eventNum, value)

func getStackAt(stackType: int, eventNum: int) -> int:
	return stackHistories[stackType].getValueAt(eventNum)

func prepareItem(item):
	return load("res://Runtime/Behavior/Core/CombatStatLoggerBehavior.gd").prepareItem(self, item)

func logItemStat(item: Item, statType: int, eventNum: int, value):
	itemTooltipHistories[item][statType].addValue(eventNum, value)

func getItemStatAt(item: Item, statType: int, eventNum: int):
	return itemTooltipHistories[item][statType].getValueAt(eventNum)

func getLastEventForStat(item: Item, statType: int, eventNum: int) -> Array:
	return itemTooltipHistories[item][statType].getLastEntryBefore(eventNum)

func logItemState(item: Item, state, eventNum: int):
	itemStateHistories[item].addValue(eventNum, state)

func hasStateData(item: Item) -> bool:
	return itemStateHistories[item].hasData()

func getItemStateAt(item: Item, eventNum: int):
	return itemStateHistories[item].getValueAt(eventNum)

func logItemMetric(item: Item, metricIndex: int, eventNum: int, value):
	itemMetricHistories[item][metricIndex].addValue(eventNum, value)

func getItemMetricAt(item: Item, metricIndex: int, eventNum: int):
	return itemMetricHistories[item][metricIndex].getValueAt(eventNum)

func logMetric(metric: int, type: int, val: int, eventNum: int):
	metricHistories[metric][type].addValueAcc(eventNum, val)

func getMetricAt(metric: int, type: int, eventNum: int) -> int:
	return metricHistories[metric][type].getValueAt(eventNum)

func printItemHistories():
	return load("res://Runtime/Behavior/Core/CombatStatLoggerBehavior.gd").printItemHistories(self)

func getValuesForMetricAt(metric: int, eventNum: int) -> Dictionary:
	return load("res://Runtime/Behavior/Core/CombatStatLoggerBehavior.gd").getValuesForMetricAt(self, metric, eventNum)

func getStatHistoriesForMetric(metric: int) -> Dictionary:
	return load("res://Runtime/Behavior/Core/CombatStatLoggerBehavior.gd").getStatHistoriesForMetric(self, metric)

