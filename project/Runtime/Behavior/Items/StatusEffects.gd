extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func pickRandomStacks(subject: Receiver, stackTypes, numStacks, target, priorityStack):
	var stacks = Dictionary()
	for stackType in stackTypes:
		var numTargetStacks = target.getStacks(stackType)
		if numTargetStacks > 0:
			stacks[stackType] = numTargetStacks

	var pickedStacks = Dictionary()

	if priorityStack != null:
		var pickedPriorityStacks = min(numStacks, stacks.get(priorityStack, 0))
		if pickedPriorityStacks > 0:
			pickedStacks[priorityStack] = pickedPriorityStacks
			numStacks -= pickedPriorityStacks
			Util.dictSub(stacks, priorityStack, pickedPriorityStacks)

	for i in numStacks:
		if not stacks.is_empty():
			var stackType = Util.pickRandomElement(stacks.keys())
			Util.dictAdd(pickedStacks, stackType, 1)
			Util.dictSub(stacks, stackType, 1)

	return pickedStacks

static func useRandomBuffs(subject: Receiver, numBuffs, triggerEvent, availableBuffs):
	var pickedBuffs = subject.pickRandomStacks(availableBuffs, numBuffs, subject.character())
	if pickedBuffs.is_empty():
		return null

	var events = []
	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in pickedBuffs:
		var event = subject.character().useStacks(buff, pickedBuffs[buff], subject, triggerEvent)
		events.push_back(event)
	EventBus.flushLoggingQueue()
	return events

static func stealRandomBuff(subject: Receiver, numBuffs, triggerEvent, possibleBuffs, priorityBuff):

	var removedStacks = subject.pickRandomStacks(possibleBuffs, numBuffs, subject.opponent(), priorityBuff)
	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in removedStacks:
		subject.opponent().loseStacks(buff, removedStacks[buff], subject, triggerEvent)

		subject.giveStacks(subject.character(), buff, removedStacks[buff], triggerEvent)
	EventBus.flushLoggingQueue()

static func getLeastStacks(subject: Receiver, numStacks, target, availableStacks):
	var priorStacks = {}
	for stackType in availableStacks:
		priorStacks[stackType] = target.getStacks(stackType)

	var pickedStacks = {}

	while numStacks > 0:
		var leastStacksCount: int = 10000
		var leastStacks = []
		for stackType in priorStacks:
			if priorStacks[stackType] < leastStacksCount:
				leastStacksCount = priorStacks[stackType]
				leastStacks.clear()
				leastStacks.push_back(stackType)
			elif priorStacks[stackType] == leastStacksCount:
				leastStacks.push_back(stackType)
		var stackToGive = Util.pickRandomElement(leastStacks)
		Util.dictAdd(pickedStacks, stackToGive, 1)
		Util.dictAdd(priorStacks, stackToGive, 1)
		numStacks -= 1

	return pickedStacks

static func getMostStacks(subject: Receiver, target, availableStacks):
	var buffs = Dictionary()
	for buff in availableStacks:
		buffs[buff] = target.getStacks(buff)

	var maxBuffs = []
	var maxStacks = 0
	for buff in buffs:
		if buffs[buff] == maxStacks:
			maxBuffs.push_back(buff)
		elif buffs[buff] > maxStacks:
			maxBuffs.clear()
			maxBuffs.push_back(buff)
			maxStacks = buffs[buff]

	return maxBuffs

static func removeMostBuffs(subject: Receiver, numBuffs, triggerEvent, use: bool, availableBuffs):
	var target

	var buffs = Dictionary()
	if use:
		target = subject.character()
	else:
		target = subject.opponent()

	var maxBuffs = subject.getMostStacks(target, availableBuffs)
	var buffToRemove = Util.pickRandomElement(maxBuffs)

	var toRemove = min(numBuffs, target.getStacks(buffToRemove))
	if toRemove == 0:
		return null

	var event
	if use:
		event = subject.character().useStacks(buffToRemove, toRemove, subject, triggerEvent)
	else:
		event = subject.opponent().loseStacks(buffToRemove, toRemove, subject, triggerEvent)
	return event

static func getStackFraction(subject: Receiver, target, fraction: float, limit: int, availableStacks):

	var sum = 0.0
	var stacksUnlimited = {}

	for buff in availableStacks:
		var prior = target.getStacks(buff)

		var withBonus = prior * fraction
		stacksUnlimited[buff] = withBonus
		sum += withBonus

	var sumRounded = round(sum)
	if sumRounded == 0: return null

	var totalToGive: float = min(limit, sumRounded)
	var limitFactor = totalToGive / sumRounded

	var buffsToGive = {}
	var overflow = {}
	var totalGiven = 0

	for buff in stacksUnlimited:
		var limited = stacksUnlimited[buff] * limitFactor
		var guaranteed = int(limited)
		buffsToGive[buff] = guaranteed
		overflow[buff] = limited - guaranteed
		totalGiven += guaranteed

	var overflowBuffs = totalToGive - totalGiven
	var sortedOverflow: Array = Util.sortDict(overflow, true)

	for buff in sortedOverflow:
		if overflowBuffs == 0:
			break

		buffsToGive[buff] += 1
		overflowBuffs -= 1

	return buffsToGive
