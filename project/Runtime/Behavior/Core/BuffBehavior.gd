extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Buff.gd")

static func init(subject: Receiver, _type, _character, _counter, _signalName):
	subject.type = _type
	subject.isBuff = Game.isBuff(subject.type)
	subject.character = _character
	subject.counter = _counter
	subject.signalName = _signalName

	subject.timer = Timer.new()
	subject.character.add_child(subject.timer)
	subject.timer.one_shot = true
	subject.timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	subject.timer.connect("timeout", Callable(subject, "onTimeout"))

	if subject.type == Game.EventType.Block:
		subject.MAX_STACKS = 100000
	else:
		subject.MAX_STACKS = 10000

	return subject

static func gainTemporary(subject: Receiver, amount: int, duration: float, item, triggerEvent, reflect: bool):

	var event = null

	if amount > 0:

		var resisted = 0
		var totalResistChance = subject.resistChancePercent

		if item != null and not reflect:
			totalResistChance -= item.getAmplificationChancePercent(subject.type)

		if totalResistChance > 0:
			for i in amount:
				if Util.flipPercent(totalResistChance):
					resisted += 1
		elif totalResistChance < 0:
			for i in amount:
				if Util.flipPercent( - totalResistChance):
					amount += 1

		var left = amount - resisted

		var reflected = 0

		if not subject.isBuff:

			if not reflect:
				for i in amount:
					if Util.flipPercent(subject.reflectChancePercent):
						reflected += 1

				left -= reflected

				var reflectedByStacks = 0
				if left > 0:
					reflectedByStacks = min(left, subject.character.debuffReflectStacks)

				if reflectedByStacks > 0:

					reflected += reflectedByStacks
					left -= reflectedByStacks
					subject.character.changeDebuffReflectStacks( - reflectedByStacks)

				if reflected > 0:
					amount -= reflected
					var target = subject.character
					Util.spawnReflectLabel(subject.type, target.randBuffLabelPos(), reflected)

			var ownStacksUsed = min(left, subject.resistStacks)
			resisted += ownStacksUsed
			left -= ownStacksUsed
			subject.resistStacks -= ownStacksUsed

			if left > 0:
				var characterStacksUsed = min(left, subject.character.debuffResistStacks)
				resisted += characterStacksUsed
				subject.character.changeDebuffResistStacks( - characterStacksUsed)

		if resisted > 0:
			amount -= resisted
			Util.spawnResistedLabel(subject.type, subject.character.randBuffLabelPos(), resisted)
			var resistedEvent = Game.combatLog.createEvent_StackResistOrNullify(subject.type,
						item, resisted, subject.character.playerId, triggerEvent, reflect)
			EventBus.logEvent(resistedEvent)

		if amount > 0:
			amount = int(min(amount, subject.MAX_STACKS - subject.current))
			if amount == 0: return null

			subject.current += amount
			subject.counter.updateHud(subject.current)

			if duration < 0:
				subject.permanentStacks += amount
			else:
				var timeout = Util.time + duration
				var tempStacks = subject.TemporaryStacks.new(amount, timeout, item)
				subject.temporaryStacks.push_back(tempStacks)

				if subject.timer.is_stopped():
					subject.timer.start(duration)
					subject.nextTemporaryTimeout = 0
				else:
					if duration < subject.timer.get_time_left():
						subject.timer.stop()
						subject.timer.start(duration)
						subject.nextTemporaryTimeout = subject.temporaryStacks.size() - 1

			if item:
				var isPlayer = (subject.character == Game.PLAYER)

				if not subject.isBuff:
					isPlayer = not isPlayer

				item.stackChanged(subject.type, amount, isPlayer)

				if duration <= 0:
					event = Game.combatLog.createEvent_Stack(subject.type, item,
						amount, subject.character.playerId, triggerEvent, false, reflect)
				else:
					event = Game.combatLog.createEvent_StackTemporary(subject.type,
						item, amount, duration, subject.character.playerId, triggerEvent,
						reflect)

				var appliedToOpponent = (subject.character != item.character())
				Util.spawnBuffLabel_item(subject.type, item, amount, appliedToOpponent)

				EventBus.emitEvent(subject.character, subject.signalName, event, [event.getAmount(), event])

		if reflected > 0:
			subject.character.opponent.gainStacksTemporary(subject.type, reflected, duration,
				item, triggerEvent, true)

	return event

static func loseStacks(subject: Receiver, amount: int, item, triggerEvent, used):

	amount = min(subject.current, amount)

	if not used:
		var protected = 0

		if subject.cleanseProtectionChancePercent > 0:
			for i in amount:
				if Util.flipPercent(subject.cleanseProtectionChancePercent):
					protected += 1

		elif subject.cleanseProtectionChancePercent < 0:
			for i in amount:
				if Util.flipPercent( - subject.cleanseProtectionChancePercent):
					protected -= 1

		amount -= protected
		amount = clamp(amount, 0, subject.current)

		if amount > 0 and subject.resistStacks > 0:
			var protectedByStacks = min(amount, subject.resistStacks)
			protected += protectedByStacks
			amount -= protectedByStacks
			subject.resistStacks -= protectedByStacks

		if (subject.isBuff and
			subject.type != Game.EventType.Block and
			amount > 0 and
			subject.character.buffProtectStacks > 0):

			var protectedByStacks = min(amount, subject.character.buffProtectStacks)
			protected += protectedByStacks
			amount -= protectedByStacks
			subject.character.buffProtectStacks -= protectedByStacks

		if protected > 0:
			Util.spawnProtectedLabel(subject.type, subject.character.randBuffLabelPos(), protected)
			var protectedEvent = Game.combatLog.createEvent_StackProtect(subject.type,
				item, protected, subject.character.playerId, triggerEvent)
			EventBus.logEvent(protectedEvent)

	if subject.permanentStacks >= amount:
		subject.permanentStacks -= amount
	else:
		var tempToCleanse = amount - subject.permanentStacks
		subject.permanentStacks = 0

		while tempToCleanse > 0:
			if subject.temporaryStacks.is_empty():
				print("current < cleanse amount")

				break

			var farthestTimeout = 0
			var farthestIndex = - 1
			for i in subject.temporaryStacks.size():
				var stacks = subject.temporaryStacks[i]
				if stacks.timeout > farthestTimeout:
					farthestTimeout = stacks.timeout
					farthestIndex = i

			var farthest = subject.temporaryStacks[farthestIndex]
			if farthest.amount > tempToCleanse:
				farthest.amount -= tempToCleanse
				tempToCleanse = 0

			else:
				tempToCleanse -= farthest.amount
				subject.temporaryStacks.remove_at(farthestIndex)

				if subject.temporaryStacks.is_empty():

					subject.timer.stop()

	return subject.changeCurrentLogShowLabel(false, amount, item, triggerEvent, used)

static func changeCurrentLogShowLabel(subject: Receiver, isTimeout: bool, amount: int, item, triggerEvent, used: bool):

	var change = min(subject.current, amount)

	if change > 0:
		subject.current -= change
		subject.counter.updateHud(subject.current)

		if item:
			var isPlayer = (subject.character == Game.PLAYER)
			if not used:
				if subject.isBuff:
					isPlayer = not isPlayer

			item.stackChanged(subject.type, - change, isPlayer, used)

			var event
			if isTimeout:
				event = Game.combatLog.createEvent_StackTimeout(subject.type, item, - change, subject.character.playerId, triggerEvent)
			else:
				event = Game.combatLog.createEvent_Stack(subject.type, item, - change, subject.character.playerId, triggerEvent, used)

			EventBus.emitEvent(subject.character, subject.signalName, event, [event.getAmount(), event])

			var appliedToOpponent = (subject.character != item.character())
			Util.spawnBuffLabel_item(subject.type, item, - change, appliedToOpponent)

			return event

	return null

static func onTimeout(subject: Receiver):
	var timedOutStacks: Receiver.TemporaryStacks = subject.temporaryStacks[subject.nextTemporaryTimeout]
	subject.changeCurrentLogShowLabel(true, timedOutStacks.amount, timedOutStacks.item)
	subject.temporaryStacks.remove_at(subject.nextTemporaryTimeout)

	if not subject.temporaryStacks.is_empty():
		var earliestTimeout = INF
		var earliestIndex = - 1
		for i in subject.temporaryStacks.size():
			var stacks = subject.temporaryStacks[i]
			if stacks.timeout < earliestTimeout:
				earliestTimeout = stacks.timeout
				earliestIndex = i

		subject.nextTemporaryTimeout = earliestIndex
		var delay = earliestTimeout - Util.time
		if delay <= 0.01:
			subject.onTimeout()
		else:
			subject.timer.start(delay)
