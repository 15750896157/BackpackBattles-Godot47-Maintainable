extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/CombatLog.gd")

static func clear(subject: Receiver):
	subject.close()
	subject.hideArrow()
	subject.scrollContainer.scrollEnabled = false
	subject.activeLine = null
	subject.unhighlightItem()
	subject.highlightedItem = null
	subject.events.clear()
	subject.logLines.clear()
	subject.delayedLogList.clear()
	subject.delayListDone = 0

	subject.eventNum = - 1

	for child in subject.container.get_children():
		assert (child is CombatLogLine)

		ObjectPool.returnInstance(child)

	subject.playerDmgMeter.clear()
	subject.opponentDmgMeter.clear()
	subject.playerDmgMeter.clearPlots()
	subject.opponentDmgMeter.clearPlots()
	Game.PLAYER.statsDisplay.reset()

	for i in 2:
		subject.statLoggers[i].clear()
	subject.activeItemState.clear()
	subject.activeCharacterStats = [[], []]
	subject.timestamps.clear()
	subject.itemsWithCooldown = [[], []]
	subject.loggingFinished = false
	for i in subject.GlobalStat.size():
		subject.globalStatHistories[i].clear()

	subject.numPlayerCharges = 0
	subject.electricalCharges.clear()
	for charge in subject.emitterEventToChargeInstance.values():
		charge.returnToObjectPool()
	subject.emitterEventToChargeInstance.clear()

static func onPrepare(subject: Receiver):
	var items = Game.PLAYER.INVENTORY.getItemsAndGems() + Game.OPPONENT.INVENTORY.getItemsAndGems()
	for character in [Game.PLAYER, Game.OPPONENT]:
		for stat in Character.Stat:
			subject.snapshotCharacterStat(character, Character.Stat[stat])

		for stackType in Game.getStacks():
			subject.snapshotStack(character, stackType)

		var statLogger: CombatStatLogger = subject.statLoggers[character.playerId]
		for item in items:

			statLogger.prepareItem(item)

		for metric in Game.ItemMetrics.values():
			for type in statLogger.metricHistories[metric]:
				statLogger.logMetric(metric, type, 0, subject.eventNum)

		subject.globalStatHistories[subject.GlobalStat.TimeAdvance].addValue(0.0, subject.eventNum)

static func onCombatEnd(subject: Receiver, roundResult):
	subject.close()

	subject.loggingFinished = true

	if roundResult == Game.RoundResult.Win:
		subject.logWin()
	else:
		subject.logLoss()

	subject.playerDmgMeter.createPlot()
	subject.opponentDmgMeter.createPlot()
	subject.scrollContainer.scrollEnabled = true

	for i in 2:
		var statLogger = subject.statLoggers[i]
		for item in statLogger.itemStateHistories:
			if statLogger.hasStateData(item):
				subject.activeItemState[item] = statLogger.getItemStateAt(item, subject.eventNum)
		for stat in statLogger.characterStatHistories:
			subject.activeCharacterStats[i].push_back(statLogger.getCharacterStatAt(stat, subject.eventNum))

	for event in subject.events:
		subject.timestamps.push_back(event.timestamp)

	for i in 2:
		for item in subject.statLoggers[i].itemTooltipHistories:

			if item.logCooldown():
				subject.itemsWithCooldown[i].push_back(item)

static func addLogLine(subject: Receiver, event):
	var logLine: CombatLogLine = ObjectPool.instantiate(subject.logLineScene)

	logLine.setEvent(event)
	logLine.visible = subject.isLineVisible(logLine)
	logLine.setMinimized(subject.isLineMinimized(logLine))
	subject.container.add_child(logLine)

	subject.logLines.push_back(logLine)
	subject.moveArrowTo(logLine, false)

	if subject.container.size.y - subject.scrollContainer.scroll_vertical < subject.scrollContainer.size.y + 50:
		if not subject.scrolledToBottom:
			Util.callNextFrame(subject, "scrollToBottom")
			subject.scrolledToBottom = true

static func unhighlightItem(subject: Receiver, modulateItem: bool):
	if subject.highlightedItem:
		if modulateItem:
			if subject.highlightedItem is Item:
				subject.highlightedItem.unhighlight()

		for line in subject.container.get_children():
			if subject.highlightedItem is Item:
				if line.getItem() == subject.highlightedItem:
					line.onConnectedHoverEnd()
			else:
				if line.getSource() == subject.highlightedItem[0]:
					line.onConnectedHoverEnd()

		if subject.highlightedItem is Item:

			subject.playerDmgMeter.unhighlightSource(subject.highlightedItem)
			subject.opponentDmgMeter.unhighlightSource(subject.highlightedItem)
		else:

			if subject.highlightedItem[1]:
				subject.playerDmgMeter.unhighlightSource(subject.highlightedItem[0])
			else:
				subject.opponentDmgMeter.unhighlightSource(subject.highlightedItem[0])

		subject.highlightedItem = null

static func replayCombat(subject: Receiver, fromStart: bool, speed):
	subject.replayingCombat = true
	subject.replaySpeed = speed
	subject.activateScrollWithArrow()

	if (subject.activeLine == null or fromStart or
		subject.activeLine.event.id == subject.events.size() - 1):
		if speed < 0:
			subject.replayTime = subject.getCombatDuration() + 0.1
			subject.scrollContainer.scroll_vertical = 100000
		else:
			subject.replayTime = 0.0
			subject.scrollContainer.scroll_vertical = 0
	else:
		subject.replayTime = subject.activeLine.event.timestamp

	Game.combatSceneNode.stopTimeTween()

static func _physics_process(subject: Receiver, delta):
	subject.call_deferred("physics_process_deferred")

	if not subject.replayingCombat: return
	subject.replayTime += delta * subject.replaySpeed

	var prevEventNum = subject.timestamps.bsearch(subject.replayTime, false) - 1

	var timeAdvance = subject.globalStatHistories[subject.GlobalStat.TimeAdvance].getValueAt(prevEventNum)

	Game.combatSceneNode.setTime(subject.replayTime + timeAdvance)

	if subject.replaySpeed > 0:
		if prevEventNum >= subject.events.size() - 1:
			subject.scrollContainer.scroll_vertical = 100000
			subject.replayFinished()
	else:
		if prevEventNum == - 1:
			prevEventNum = 0
			subject.scrollContainer.scroll_vertical = 0
			subject.replayFinished()

	var prevEvent = subject.events[prevEventNum]
	var logLine = subject.logLines[prevEventNum]

	if subject.activeLine != logLine:

		var timestamp = subject.timestamps[prevEventNum]
		var firstPrevEventNum = prevEventNum

		while firstPrevEventNum > 0:
			firstPrevEventNum -= 1
			if timestamp != subject.timestamps[firstPrevEventNum]:
				break

		for eventI in range(firstPrevEventNum + 1, prevEventNum + 1):
			var event: CombatEvent = subject.events[eventI]
			subject.replayAnimation(event)

		subject.onLineHoverEnd()
		subject.moveArrowTo(logLine, false)
		subject.replayLogLineEvent(logLine)
		subject.replayElectricalCharges(logLine.event)

	subject.updateDisplayCooldowns(prevEvent)
	subject.playerDmgMeter.setTime(subject.replayTime)
	subject.opponentDmgMeter.setTime(subject.replayTime)

static func updateDisplayCooldowns(subject: Receiver, event):
	for i in 2:
		var statLogger: CombatStatLogger = subject.statLoggers[i]
		for item in subject.itemsWithCooldown[i]:
			var lastEntry = statLogger.getLastEventForStat(item, Item.Stat.Cooldown, event.id)
			var lastEntry_EventNum = lastEntry[0]
			if lastEntry_EventNum >= subject.events.size():

				print("eventnum exceeded")
				lastEntry_EventNum = subject.events.size() - 1
			var timeSinceEntry: float
			if subject.replayingCombat:
				timeSinceEntry = subject.replayTime - subject.getTimeOfEvent(lastEntry_EventNum)
			else:
				timeSinceEntry = event.timestamp - subject.getTimeOfEvent(lastEntry_EventNum)
			var encodedCd = lastEntry[1]

			item.reconstructCooldown(encodedCd, timeSinceEntry)

static func onLineHovered(subject: Receiver, logLine: CombatLogLine):
	if subject.replayingCombat:
		return

	var event: CombatEvent = logLine.event

	subject.moveArrowTo(logLine, true)
	subject.showArrow()
	var timeAdvance = subject.globalStatHistories[subject.GlobalStat.TimeAdvance].getValueAt(event.id)

	var time = event.timestamp + timeAdvance
	subject.replayTime = time

	Game.combatSceneNode.interpolateTime(time)
	subject.replayLogLineEvent(logLine)
	subject.updateDisplayCooldowns(event)

	subject.unhighlightItem()
	var item = logLine.getItem()
	if item != null:
		subject.highlightItem(item)

	else:
		var source = logLine.getSource()
		if source:
			subject.highlightSource(source, event.getMainActor() == Character.ID.PLAYER)

	subject.replayAnimation(event)

	subject.replayElectricalCharges(event)

static func replayLogLineEvent(subject: Receiver, logLine: CombatLogLine):
	var event: CombatEvent = logLine.event
	for i in 2:
		var statLogger: CombatStatLogger = subject.statLoggers[i]
		var character = subject.getCharacterFromId(i)
		for stat in Character.Stat.values():
			if stat == Character.Stat.Stamina:
				pass
			var value = statLogger.getCharacterStatAt(stat, event.id)
			if value != subject.activeCharacterStats[i][stat]:
				character.setStat(stat, value)
				character.statsDisplay.onStatChanged(stat, value)
				subject.activeCharacterStats[i][stat] = value

		for stack in statLogger.stackHistories:
			var numStacks = statLogger.getStackAt(stack, event.id)

			character.setStacks(stack, numStacks)

		for item in statLogger.itemTooltipHistories:
			for stat in Item.Stat.values():
				item.setStat(stat, statLogger.getItemStatAt(item, stat, event.id))

		for item in statLogger.itemStateHistories:
			if statLogger.hasStateData(item):

				var state = statLogger.getItemStateAt(item, event.id)
				if not Util.equals(state, subject.activeItemState[item]):
					item.onStateChanged(state)
					subject.activeItemState[item] = state

		subject.updateDamageMeter(i, event)

	if subject.isLineVisible(logLine) and subject.isLineMinimized(logLine):

		if subject.tooltip != null:
			subject.tooltip.queue_free()
		subject.tooltip = subject.logLineTooltipScene.instantiate()
		subject.tooltipNode.add_child(subject.tooltip)
		var tooltipLogLine = subject.tooltip.get_node("VBoxContainer/LogLine")
		tooltipLogLine.setEvent(event)
		tooltipLogLine.setStylebox(tooltipLogLine.State.Tooltip)
		subject.tooltip.updateSize()
		var toolPos = logLine.global_position
		toolPos.x -= 20
		toolPos.y += 50
		var toolSize = Vector2(subject.size.x, logLine.size.y)

		subject.tooltip.forceUpdatePosition(toolPos, toolSize)

static func createEvent_Attack(subject: Receiver, damageRes, triggerEvent):
	var event
	var origin = damageRes.damageSource.origin
	var character = origin.character()

	if damageRes.hasHit():

		if damageRes.wasCriticalHit():
			event = subject.createEvent(triggerEvent, origin, Game.EventType.CriticalDamage)
		else:
			event = subject.createEvent(triggerEvent, origin, Game.EventType.DealDamage)
		event.setParam("damage", damageRes.damage)

		var attackedCharacter
		if damageRes.damageSource.hasType(DamageSource.Type.SelfDamage):
			attackedCharacter = character
		else:
			attackedCharacter = character.opponent
		subject.snapshotCharacterStat(attackedCharacter, Character.Stat.Health)
		subject.snapshotStack(attackedCharacter, Game.EventType.Block)
		subject.updateDamageMeter(attackedCharacter.playerId, event)
	else:
		event = subject.createEvent(triggerEvent, origin, Game.EventType.MissedAttack)

	return event

static func createEvent_Damage(subject: Receiver, damageRes: DamageResult, damagingPlayerId, triggerEvent):

	var event
	if damageRes.wasCriticalHit():
		event = subject.createEvent(triggerEvent, damageRes.damageSource.types[0],
			Game.EventType.CriticalDamage)
	else:
		event = subject.createEvent(triggerEvent, damageRes.damageSource.types[0],
			Game.EventType.DealDamage)
	event.setParam("damage", damageRes.damage)
	event.setTarget(damagingPlayerId)
	var damagingCharacter = subject.getCharacterFromId(damagingPlayerId)
	var damagedCharacter = damagingCharacter.opponent
	subject.snapshotCharacterStat(damagedCharacter, Character.Stat.Health)
	subject.snapshotStack(damagedCharacter, Game.EventType.Block)
	subject.snapshotDamageDealt(damagingPlayerId, damageRes.damageSource.types[0], damageRes.damage)
	subject.updateDamageMeter(damagingPlayerId, event)
	return event

static func createEvent_Stack(subject: Receiver, type: int, item: Item, amount: int, playerId: int, triggerEvent: CombatEvent, used: bool, reflected: bool):

	var event = subject.createEvent(triggerEvent, item, type)
	event.setParam("amount", amount)
	event.setParam("used", used)
	event.setParam("reflected", reflected)
	event.setTarget(playerId)
	subject.snapshotStack(subject.getCharacterFromId(playerId), type)

	if type == Game.EventType.Empower:
		for affected_item in subject.getCharacterFromId(playerId).INVENTORY.getItems():
			if affected_item.isWeapon() and affected_item.canBeEmpowered():
				subject.snapshotItemTooltipStat(affected_item, Item.Stat.MinDamage)
				subject.snapshotItemTooltipStat(affected_item, Item.Stat.MaxDamage)

	if type == Game.EventType.Heat or type == Game.EventType.Cold:
		for affected_item in subject.getCharacterFromId(playerId).INVENTORY.getItems():
			if affected_item.hasCooldown():
				subject.snapshotItemTooltipStat(affected_item, Item.Stat.Speed)
				subject.snapshotItemTooltipStat(affected_item, Item.Stat.Cooldown)

	if type == Game.EventType.Lucky or type == Game.EventType.Blind:
		for affected_item in subject.getCharacterFromId(playerId).INVENTORY.getItems():
			if affected_item.isWeapon():
				subject.snapshotItemTooltipStat(affected_item, Item.Stat.Accuracy)

	return event

static func createEvent_DamChange(subject: Receiver, item, amount: float, isPercent: bool, duration, type, triggerEvent):

	var event = null
	if amount > 0:
		event = subject.createEvent(triggerEvent, item, Game.EventType.DamIncrease)
	else:
		event = subject.createEvent(triggerEvent, item, Game.EventType.DamReduction)

	event.setParam("amount", amount)
	event.setParam("isPercent", isPercent)
	if duration != null:
		event.setParam("duration", duration)
	if type != null:
		event.setParam("type", type)
	return event

static func updateIdle(subject: Receiver) -> void :

	if subject.activeLine != null:
		var lastVisibleLine = subject.getLastVisibleLine()
		if lastVisibleLine == null: return

		var pos = lastVisibleLine.global_position.y + lastVisibleLine.size.y * 0.5
		var containerStart = subject.scrollContainer.global_position.y
		var containerEnd = containerStart + subject.scrollContainer.size.y

		if subject.scrollWithArrow:

			var diffToTop = (containerStart + 20) - pos
			if diffToTop > 0:
				subject.scrollContainer.scroll_vertical -= diffToTop
				pos += diffToTop

			var diffToBottom = pos - containerEnd + 20
			if diffToBottom > 0:
				subject.scrollContainer.scroll_vertical += diffToBottom
				pos -= diffToBottom
		else:
			if containerEnd + 20 < pos or pos < containerStart - 20:
				subject.lineArrow.hide()
			else:
				subject.lineArrow.show()

		subject.lineArrow.global_position.y = pos

static func isLineMinimized(subject: Receiver, line: CombatLogLine) -> bool:
	if not subject.showPlayerEvents and line.player:
		return true

	if not subject.showOpponentEvents and not line.player:
		return true

	if (line.getType() == Game.EventType.Activation and
		subject.activationsState == subject.ActivationsState.Minimized):
		return true

	if subject.searchTerm != "":
		if line.getText().findn(subject.searchTerm) == - 1:
			return true

	return false

static func getLastVisibleLine(subject: Receiver) -> CombatLogLine:
	if subject.activeLine == null:
		if subject.logLines.is_empty():
			return null
		return subject.logLines[0]

	var lastVisibleLine: CombatLogLine = null

	for line in subject.logLines:
		if line.visible:
			lastVisibleLine = line
		if line == subject.activeLine:
			break

	if lastVisibleLine == null:
		for line in subject.logLines:
			if line.visible:
				lastVisibleLine = line
				break

	return lastVisibleLine

static func onFilterChanged(subject: Receiver):
	if subject.activeLine != null:
		subject.activeLineYBeforeFilterChange = subject.activeLine.global_position.y

	for line in subject.container.get_children():
		line.visible = subject.isLineVisible(line)
		line.setMinimized(subject.isLineMinimized(line))

	if subject.activeLine != null:

		subject.activeLine = subject.getLastVisibleLine()

		if subject.activeLine != null:
			subject.lineArrow.hide()
			Util.callNextFrame(subject, "updateScroll")

static func onCursorWarp(subject: Receiver):
	if subject.visible:
		for node in subject.warpPointNodes:
			if node.is_visible_in_tree() and Util.isControlEnabled(node):
				Game.addControlOfInterest(node, Vector2.ZERO, null, null, 1)
		for line in subject.logLines:
			Game.addControlOfInterest(line, Vector2.ZERO, subject.scrollContainer, line, 1)

		for dmgMeter in [subject.playerDmgMeter, subject.opponentDmgMeter]:
			for plot in dmgMeter.plots:
				for entry in dmgMeter.plotToEntry.get(plot, []):
					Game.addControlOfInterest(entry, Vector2(60, 10),
						dmgMeter.scrollContainer, entry, 1)

static func logElectricalCharge(subject: Receiver, emitterEvent: CombatEvent, duration: float, cells: Array):

	if emitterEvent == null:
		Util.eprint("Charge event null")
		return

	var data = subject.ElectricalChargeData.new(emitterEvent, duration, cells)
	subject.electricalCharges.push_back(data)

	if emitterEvent.origin.character() == Game.PLAYER:
		subject.numPlayerCharges += 1

	if subject.numPlayerCharges == 10:
		SteamHelper.unlockAchievement("Charges", false)

static func replayElectricalCharges(subject: Receiver, event: CombatEvent):
	var newChargeInstances = {}

	for chargeData in subject.electricalCharges:
		var progress = chargeData.getProgressAt(event)
		if progress >= 0:
			var charge = subject.emitterEventToChargeInstance.get(chargeData)
			if charge == null:
				charge = ObjectPool.instantiate(Game.electricalChargeScene)
				Game.playerNode.add_child(charge)

			newChargeInstances[chargeData] = charge

			var stop = not subject.replayingCombat or subject.replaySpeed < 0

			charge.seek(chargeData.emitterEvent.origin, chargeData.cells,
				chargeData.duration, progress, stop)

	for chargeData in subject.emitterEventToChargeInstance:
		if not chargeData in newChargeInstances:
			var charge = subject.emitterEventToChargeInstance[chargeData]
			charge.returnToObjectPool()

	subject.emitterEventToChargeInstance = newChargeInstances
