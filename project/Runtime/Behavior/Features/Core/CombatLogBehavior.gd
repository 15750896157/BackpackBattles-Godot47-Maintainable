extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/CombatLog.gd")

static func createEvent(subject: Receiver, triggerEvent, origin, type) -> CombatEvent:
	subject.eventNum += 1

	var event = CombatEvent.new(subject.eventNum, subject.getTimeStamp(), triggerEvent,
				origin, type)

	for character in [Game.PLAYER, Game.OPPONENT]:
		subject.snapshotCharacterStat(character, Character.Stat.Stamina)

	return event

static func logEvent(subject: Receiver, event, afterFightAllowed):
	if Game.fightEnded and not afterFightAllowed: return

	subject.eventsLogged += 1
	if not subject.visible:
		subject.delayedLogList.append(event)

	else:
		subject.addLogLine(event)

	subject.events.push_back(event)

static func highlightItem(subject: Receiver, item, modulateItem: bool):
	if modulateItem:
		item.highlight()
	subject.highlightedItem = item

	for line in subject.container.get_children():
		if line.getItem() == subject.highlightedItem:
			line.onConnectedHovered()

	subject.playerDmgMeter.highlightSource(subject.highlightedItem)
	subject.opponentDmgMeter.highlightSource(subject.highlightedItem)

static func highlightSource(subject: Receiver, source, player):
	subject.highlightedItem = [source, player]

	for line in subject.container.get_children():
		if line.getSource() == source and line.player == player:
			line.onConnectedHovered()

	if player:
		subject.playerDmgMeter.highlightSource(source)
	else:
		subject.opponentDmgMeter.highlightSource(source)

static func physics_process_deferred(subject: Receiver):

	if subject.eventsLogged <= 0:

		if Game.fightEnded:
			for i in 10:
				var done = subject.replayDelayedEvent()
				if done: break
		else:
			subject.replayDelayedEvent()

	subject.eventsLogged = 0

static func snapshotItemMetric(subject: Receiver, item, metricIndex, playerId, withNextEvent):
	if playerId == null:
		playerId = item.character().playerId

	var connectedEventNum = subject.eventNum
	if withNextEvent:
		connectedEventNum += 1
	subject.statLoggers[playerId].logItemMetric(item, metricIndex,
		connectedEventNum, item.getMetric(metricIndex))

static func snapshotItemTooltipStat(subject: Receiver, item, statType, playerId, withNextEvent, event):

	if playerId == null:
		playerId = item.character().playerId

	var connectedEventNum = subject.eventNum
	if event != null:
		connectedEventNum = event.id
	elif withNextEvent:
		connectedEventNum += 1

	subject.statLoggers[playerId].logItemStat(item,
		statType, connectedEventNum, item.getStat(statType))

	item.queueTooltipUpdate()

static func snapshotItemState(subject: Receiver, item, state, withNextEvent: bool, event: CombatEvent):
	var playerId = item.character().playerId
	var connectedEventNum = subject.eventNum
	if event != null:
		connectedEventNum = event.id
	elif withNextEvent:
		connectedEventNum += 1

	subject.statLoggers[playerId].logItemState(item, state, connectedEventNum)

	if subject.loggingFinished:
		subject.activeItemState[item] = state

static func snapshotCharacterStat(subject: Receiver, character: Character, stat: int, withNextEvent: bool, event: CombatEvent):
	var connectedEventNum = subject.eventNum
	if event != null:
		connectedEventNum = event.id
	elif withNextEvent:
		connectedEventNum += 1
	var statValue = character.getStat(stat)
	subject.statLoggers[character.playerId].logCharacterStat(stat, connectedEventNum,
		statValue)
	character.statsDisplay.onStatChanged(stat, statValue)

static func replayAnimation(subject: Receiver, event):
	var origin = event.getOrigin()
	if origin is Item:
		origin.activateFromEvent(event)
	else:
		var targetId = event.target
		if event.hasParam("damage"):
			targetId = subject.getOtherCharacterId(targetId)
		subject.getCharacterFromId(targetId).replayEvent(event)

static func createEvent_Heal(subject: Receiver, amount: int, playerId: int, origin, triggerEvent: CombatEvent):

	var event = subject.createEvent(triggerEvent, origin, Game.EventType.Health)
	event.setParam("amount", amount)
	event.setTarget(playerId)
	subject.snapshotCharacterStat(subject.getCharacterFromId(playerId), Character.Stat.Health)
	return event

static func createEvent_LoseHealth(subject: Receiver, amount: int, playerId: int, origin, triggerEvent: CombatEvent):

	var event = subject.createEvent(triggerEvent, origin, Game.EventType.LoseHealth)
	event.setParam("amount", amount)
	event.setTarget(playerId)
	subject.snapshotCharacterStat(subject.getCharacterFromId(playerId), Character.Stat.Health)
	return event

static func createEvent_StackTemporary(subject: Receiver, type, item, amount, duration, playerId, triggerEvent, reflected: bool):
	var event = subject.createEvent_Stack(type, item, amount, playerId, triggerEvent)
	event.setParam("duration", duration)
	event.setParam("reflected", reflected)
	return event

static func createEvent_StackResistOrNullify(subject: Receiver, type, item, amount, playerId, triggerEvent, reflect: bool):
	var event = subject.createEvent_Stack(type, item, amount, playerId, triggerEvent)
	event.setParam("resisted", true)
	event.setParam("reflected", reflect)
	return event

static func createEvent_Stun(subject: Receiver, item, duration, playerId, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.Stun)
	event.setParam("duration", duration)
	event.setTarget(playerId)
	return event

static func createEvent_InvulnerableStart(subject: Receiver, item, duration, playerId, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.InvulnerableStart)
	event.setParam("duration", duration)
	event.setTarget(playerId)
	return event

static func createEvent_Stamina(subject: Receiver, amount, item, playerId, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.Stamina)
	event.setParam("stamina", floor(amount * 10) / 10.0)
	event.setTarget(playerId)
	return event

static func createEvent_DrainStamina(subject: Receiver, amount, item, playerId, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.DrainStamina)
	event.setTarget(playerId)
	event.setParam("stamina", floor(amount * 10) / 10.0)
	return event

static func createEvent_DamageBuff(subject: Receiver, item, buffedItem, damage, playerId, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.DamageBuff)
	event.setTarget(playerId)
	event.setParam("item", buffedItem.getTranslatedName())
	event.setParam("damage", damage)
	return event

static func createEvent_TemporaryMaxHealth(subject: Receiver, item, amount, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.TemporaryMaxHealth)
	event.setParam("amount", amount)
	subject.snapshotCharacterStat(item.character(), Character.Stat.Health)
	subject.snapshotCharacterStat(item.character(), Character.Stat.MaxHealth)
	return event

static func createEvent_TemporaryMaxStamina(subject: Receiver, item, amount, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.TemporaryMaxStamina)
	event.setParam("stamina", amount)
	subject.snapshotCharacterStat(item.character(), Character.Stat.Stamina)
	subject.snapshotCharacterStat(item.character(), Character.Stat.MaxStamina)
	return event

static func createEvent_Reincarnate(subject: Receiver, item, health: int, triggerEvent):
	var event = subject.createEvent(triggerEvent, item, Game.EventType.Reincarnate)
	event.setParam("health", health)
	subject.snapshotCharacterStat(item.character(), Character.Stat.Health)
	return event

static func close(subject: Receiver) -> void :
	subject.hide()

	subject.buttonHint.translationKey = "BUTTON_OpenLog"
	subject.buttonHint.updateText()

	subject.dragging = false
	subject.scrollTimer.stop()
	subject.endDragging()
	subject.onHorizontalResizeButtonUp()
	subject.onVerticalResizeButtonUp()
	subject.scrollContainer.onClose()

	if subject.replayingCombat:
		subject.replayFinished()

static func onScrollbarVisibilityChanged(subject: Receiver):
	if subject.scrollContainer.get_v_scroll_bar().visible:
		subject.scrollContainer.size.x = subject.size.x - 8
	else:
		subject.scrollContainer.size.x = subject.size.x - 35

static func getNextVisibleLine(subject: Receiver) -> CombatLogLine:

	var index = subject.logLines.find(subject.activeLine)

	while true:
		index += 1
		index %= subject.logLines.size()
		if subject.logLines[index].visible:
			return subject.logLines[index]

	return subject.activeLine

static func getPreviousVisibleLine(subject: Receiver) -> CombatLogLine:
	var index = subject.logLines.find(subject.activeLine)

	while true:
		index = (index - 1 + subject.logLines.size()) % subject.logLines.size()
		if subject.logLines[index].visible:
			return subject.logLines[index]

	return subject.activeLine

static func scrollTimerTimeout(subject: Receiver):
	if Util.isActionPressed("shift_down"):
		var nextLine = subject.getNextVisibleLine()
		subject.onLineHovered(nextLine)
		subject.scrollTimer.start(0.1)

	elif Util.isActionPressed("shift_up"):
		var nextLine = subject.getPreviousVisibleLine()
		subject.onLineHovered(nextLine)
		subject.scrollTimer.start(0.1)

static func onGetRects(subject: Receiver):
	if subject.visible:
		Game.addOcclusion(subject.global_position, subject.size, 0)

	for dmgMeter in [subject.playerDmgMeter, subject.opponentDmgMeter]:
		if dmgMeter.isVisible():
			Game.addOcclusion(dmgMeter.global_position, dmgMeter.size, 0)
