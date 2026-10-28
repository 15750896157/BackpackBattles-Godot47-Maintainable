extends RefCounted
class_name StatHistory

var eventNumbers = []
var values = []

func addValue(eventNum, value):
	return load("res://Runtime/Callbacks/Core/CallbacksS.gd").ForStatHistory.addValue(self, eventNum, value)

func hasData() -> bool:
	return eventNumbers.size() > 1

func clear():
	eventNumbers.clear()
	values.clear()

func getValueAt(eventNum):
	return load("res://Runtime/Callbacks/Core/CallbacksS.gd").ForStatHistory.getValueAt(self, eventNum)

func getLastEntryBefore(eventNum):

	var index = eventNumbers.bsearch(eventNum, false) - 1
	return [eventNumbers[index], values[index]]

func addValueAcc(eventNum, value):
	var curValue = 0
	if not values.is_empty():
		curValue = values[ - 1]
	addValue(eventNum, curValue + value)
