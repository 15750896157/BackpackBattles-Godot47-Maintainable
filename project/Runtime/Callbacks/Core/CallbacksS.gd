extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForStatHistory:
	const Receiver = preload("res://Core/StatHistory.gd")

	static func addValue(subject: Receiver, eventNum, value):
		if subject.values.is_empty() or not Util.equals(subject.values[ - 1], value):
			subject.eventNumbers.push_back(eventNum)
			subject.values.push_back(value)

	static func getValueAt(subject: Receiver, eventNum):

		if eventNum < 0:
			return subject.values[0]

		if subject.eventNumbers[ - 1] <= eventNum:
			return subject.values[ - 1]

		var index = subject.eventNumbers.bsearch(eventNum, false) - 1
		return subject.values[index]
