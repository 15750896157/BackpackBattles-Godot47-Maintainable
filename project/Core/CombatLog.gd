extends ResizableControl

signal replay_finished

enum ActivationsState{
	Hide = 0,
	Minimized = 1,
	Show = 2,
}

enum GlobalStat{
	TimeAdvance = 0,
}

const logLineScene = preload("res://Interface/CombatLog/CombatLogLine.tscn")
const logLineTooltipScene = preload("res://Interface/CombatLog/LogLineTooltip.tscn")

const playerStyleboxes = [
	preload("res://Interface/CombatLog/LogLinePlayerStylebox.tres"),
	preload("res://Interface/CombatLog/LogLinePlayerStylebox_hovered.tres"),
	preload("res://Interface/CombatLog/LogLinePlayerStylebox_connected.tres"),
	preload("res://Interface/CombatLog/LogLinePlayerStylebox_tooltip.tres")
]

const opponentStyleboxes = [
	preload("res://Interface/CombatLog/LogLineOpponentStylebox.tres"),
	preload("res://Interface/CombatLog/LogLineOpponentStylebox_hovered.tres"),
	preload("res://Interface/CombatLog/LogLineOpponentStylebox_connected.tres"),
	preload("res://Interface/CombatLog/LogLineOpponentStylebox_tooltip.tres")
]

var fadedStyleboxes: Dictionary

@onready var scrollContainer = $ScrollContainer
@onready var container = $ScrollContainer/VBoxContainer
@onready var lineArrow = $LineArrow
@onready var hoverHint = $HoverHint
@onready var dragHint = $DragHint
@onready var buttonHint = Game.combatSceneNode.get_node("%CombatLogButtonHint")
@onready var tutorialAni = Game.combatSceneNode.get_node("%CombatLogTutorialAnimation")
@onready var buttonTutorialAni = $TutorialAni
@onready var playerDmgMeter = $PlayerDamageMeter
@onready var opponentDmgMeter = $OpponentDamageMeter
@onready var playerButton = $PlayerButton
@onready var opponentButton = $OpponentButton
@onready var filterPanel = $FilterPanel
@onready var searchBar = $FilterPanel/Searchbar
@onready var tooltipNode = $AboveLog
@onready var scrollTimer = $ScrollTimer
@onready var closeButton = $CloseButton

var arrowTween
var scrollWithArrow: bool = false
var tooltip = null
var warpPointNodes: Array

var events = []
var eventNum = - 1
var timestamps = []
var logLines = []
var activeLine: CombatLogLine = null
var loggingFinished = false
var statLoggers = [CombatStatLogger.new(0), CombatStatLogger.new(1)]
var globalStatHistories = []
var activeItemState = {}
var activeCharacterStats = [[], []]
var itemsWithCooldown = [[], []]

var electricalCharges = []
var emitterEventToChargeInstance = {}
var numPlayerCharges = 0

var showPlayerEvents = true
var showOpponentEvents = true
var activationsState: int = ActivationsState.Hide
var searchTerm: String

func _ready() -> void :
	super._ready()

	get_parent().show()
	hide()
	hideArrow()
	get_tree().connect("process_frame", Callable(self, "updateIdle"))
	Game.connect("shop_closed", Callable(self, "onPrepare"))
	Game.connect("combat_end", Callable(self, "onCombatEnd"))
	Game.connect("switch_to_shop", Callable(self, "clear"))
	Game.connect("return_to_title", Callable(self, "clear"))
	Game.connect("return_to_history", Callable(self, "clear"))
	Game.connect("warp_cursor_combat", Callable(self, "onCursorWarp"))
	Game.connect("get_rects_combat", Callable(self, "onGetRects"))

	var scrollBar = scrollContainer.get_v_scroll_bar()
	scrollBar.connect("visibility_changed", Callable(self, "onScrollbarVisibilityChanged"))
	searchBar.connect("search_text_changed", Callable(self, "onSearchTextChanged"))

	playerDmgMeter.connect("drag_start", Callable(self, "startDragging"))
	playerDmgMeter.connect("drag_end", Callable(self, "endDragging"))

	opponentDmgMeter.connect("drag_start", Callable(self, "startDragging"))
	opponentDmgMeter.connect("drag_end", Callable(self, "endDragging"))

	filterPanel.connect("drag_start", Callable(self, "startDragging"))
	filterPanel.connect("drag_end", Callable(self, "endDragging"))

	$PlayerButton.connect("toggled", Callable(self, "onPlayerToggled"))
	$OpponentButton.connect("toggled", Callable(self, "onOpponentToggled"))

	for stylebox in playerStyleboxes:
		var fadedStylebox = stylebox.duplicate()
		fadedStylebox.bg_color.a *= 0.8
		fadedStyleboxes[stylebox] = fadedStylebox

	for stylebox in opponentStyleboxes:
		var fadedStylebox = stylebox.duplicate()
		fadedStylebox.bg_color.a *= 0.6
		fadedStyleboxes[stylebox] = fadedStylebox

	scrollContainer.onClose()

	for globalStat in GlobalStat:
		globalStatHistories.push_back(StatHistory.new())

	if not Expedition.enabled: ObjectPool.prepare(logLineScene, 12)

	warpPointNodes = Util.getInteractableNodes(self)

func clear():
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").clear(self)

func onPrepare():
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").onPrepare(self)

func onCombatEnd(roundResult):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").onCombatEnd(self, roundResult)

func getTimeStamp():
	return Game.combatTimer.getTimeStamp()

func getCharacterFromId(id):
	if id == Character.ID.PLAYER:
		return Game.PLAYER
	else:
		return Game.OPPONENT

func getOtherCharacterId(id) -> int:
	return 1 - id

var scrolledToBottom = false

func createEvent(triggerEvent, origin, type) -> CombatEvent:
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent(self, triggerEvent, origin, type)

var delayedLogList = []
var delayListDone = 0
var eventsLogged = 0

func replayDelayedEvent() -> bool:
	if delayListDone < delayedLogList.size():
		var eventToReplay = delayedLogList[delayListDone]
		catchUpEvent(eventToReplay)

		delayListDone += 1
		return false

	return true

func logEvent(event, afterFightAllowed = false):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").logEvent(self, event, afterFightAllowed)

func catchUpEvent(event):
	addLogLine(event)

func addLogLine(event):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").addLogLine(self, event)

var highlightedItem = null

func unhighlightItem(modulateItem: bool = true):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").unhighlightItem(self, modulateItem)

func highlightItem(item, modulateItem: bool = true):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").highlightItem(self, item, modulateItem)

func highlightSource(source, player):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").highlightSource(self, source, player)

func scrollToBottom():
	scrollContainer.scroll_vertical = 10000
	scrolledToBottom = false

func activateScrollWithArrow():
	scrollWithArrow = true
	lineArrow.show()

var replayingCombat: bool = false
var replayTime: float
var replaySpeed: float

func replayCombat(fromStart: bool, speed = 1.0):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").replayCombat(self, fromStart, speed)

func replayFinished():
	stopReplay()
	emit_signal("replay_finished")

func stopReplay():
	replayingCombat = false
	scrollWithArrow = false

	for event in emitterEventToChargeInstance:
		var charge = emitterEventToChargeInstance[event]
		charge.stop()

func physics_process_deferred():
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").physics_process_deferred(self)

func _physics_process(delta):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd")._physics_process(self, delta)

func snapshotStack(character, stackType):
	statLoggers[character.playerId].logStack(stackType, eventNum, character.getStacks(stackType))

func snapshotDamageDealt(playerId, damageType, damage):
	statLoggers[playerId].logMetric(Game.ItemMetrics.Damage, damageType, damage, eventNum)

func snapshotMetric(playerId, metric, eventType, value):
	statLoggers[playerId].logMetric(metric, eventType, value, eventNum)

func snapshotItemMetric(item, metricIndex, playerId = null, withNextEvent = false):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").snapshotItemMetric(self, item, metricIndex, playerId, withNextEvent)

func snapshotItemTooltipStat(item, statType, playerId = null,
	withNextEvent = false, event = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").snapshotItemTooltipStat(self, item, statType, playerId, withNextEvent, event)

func snapshotItemState(item, state, withNextEvent: bool, event: CombatEvent):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").snapshotItemState(self, item, state, withNextEvent, event)

func snapshotCharacterStat(character: Character, stat: int,
	withNextEvent: bool = false, event: CombatEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").snapshotCharacterStat(self, character, stat, withNextEvent, event)

func updateDisplayCooldowns(event):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").updateDisplayCooldowns(self, event)

func onLineHovered(logLine: CombatLogLine):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").onLineHovered(self, logLine)

func replayAnimation(event):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").replayAnimation(self, event)

func replayLogLineEvent(logLine: CombatLogLine):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").replayLogLineEvent(self, logLine)

func onLineHoverEnd():
	if tooltip != null:
		tooltip.queue_free()
		tooltip = null

func updateDamageMeter(playerId, event):
	if playerId == 0:
		playerDmgMeter.updateMeter(event, statLoggers[playerId])
	else:
		opponentDmgMeter.updateMeter(event, statLoggers[playerId])

func createEvent_Attack(damageRes, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").createEvent_Attack(self, damageRes, triggerEvent)

func createEvent_Damage(damageRes: DamageResult, damagingPlayerId, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").createEvent_Damage(self, damageRes, damagingPlayerId, triggerEvent)

func createEvent_Heal(amount: int, playerId: int, origin,
	triggerEvent: CombatEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_Heal(self, amount, playerId, origin, triggerEvent)

func createEvent_LoseHealth(amount: int, playerId: int, origin,
	triggerEvent: CombatEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_LoseHealth(self, amount, playerId, origin, triggerEvent)

func createEvent_Stack(type: int, item: Item, amount: int,
	playerId: int, triggerEvent: CombatEvent = null,
	used: bool = false, reflected: bool = false):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").createEvent_Stack(self, type, item, amount, playerId, triggerEvent, used, reflected)

func createEvent_StackTemporary(type, item, amount, duration, playerId,
	triggerEvent, reflected: bool = false):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_StackTemporary(self, type, item, amount, duration, playerId, triggerEvent, reflected)

func createEvent_StackTimeout(type, item, amount, playerId, triggerEvent):
	var event = createEvent_Stack(type, item, amount, playerId, triggerEvent)
	event.setParam("timeout", true)
	return event

func createEvent_StackResistOrNullify(type, item, amount, playerId, triggerEvent,
	reflect: bool = false):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_StackResistOrNullify(self, type, item, amount, playerId, triggerEvent, reflect)

func createEvent_StackProtect(type, item, amount, playerId, triggerEvent):
	var event = createEvent_Stack(type, item, amount, playerId, triggerEvent)
	event.setParam("protected", true)
	return event

func createEvent_Stun(item, duration, playerId, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_Stun(self, item, duration, playerId, triggerEvent)

func createEvent_StunResist(item, playerId, triggerEvent = null):
	var event = createEvent(triggerEvent, item, Game.EventType.StunResisted)
	event.setTarget(playerId)
	return event

func createEvent_InvulnerableStart(item, duration, playerId, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_InvulnerableStart(self, item, duration, playerId, triggerEvent)

func createEvent_InvulnerableEnd(item, playerId, triggerEvent = null):
	var event = createEvent(triggerEvent, item, Game.EventType.InvulnerableEnd)
	event.setTarget(playerId)
	return event

func createEvent_Stamina(amount, item, playerId, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_Stamina(self, amount, item, playerId, triggerEvent)

func createEvent_DrainStamina(amount, item, playerId, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_DrainStamina(self, amount, item, playerId, triggerEvent)

func createEvent_OutOfStamina(item, playerId, triggerEvent = null):
	var event = createEvent(triggerEvent, item, Game.EventType.OutofStamina)
	event.setTarget(playerId)
	return event

func createEvent_DamageBuff(item, buffedItem, damage, playerId, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_DamageBuff(self, item, buffedItem, damage, playerId, triggerEvent)

func createEvent_TemporaryMaxHealth(item, amount, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_TemporaryMaxHealth(self, item, amount, triggerEvent)

func createEvent_TemporaryMaxStamina(item, amount, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_TemporaryMaxStamina(self, item, amount, triggerEvent)

func createEvent_BattleRageStart(item, duration, triggerEvent = null):
	var event = createEvent(triggerEvent, item, Game.EventType.BattleRageStart)
	event.setParam("duration", duration)
	return event

func createEvent_BattleRageEnd(playerId, triggerEvent = null):
	var event = createEvent(triggerEvent, Game.EventType.BattleRageEnd,
		Game.EventType.BattleRageEnd)
	event.setTarget(playerId)
	return event

func createEvent_Reincarnate(item, health: int, triggerEvent = null):
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").createEvent_Reincarnate(self, item, health, triggerEvent)

func createEvent_Activation(item, triggerEvent = null):
	var event = createEvent(triggerEvent, item, Game.EventType.Activation)
	return event

func createEvent_DamChange(item, amount: float, isPercent: bool,
	duration = null, type = null, triggerEvent = null):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").createEvent_DamChange(self, item, amount, isPercent, duration, type, triggerEvent)

func logWin():
	var event = createEvent(null, Game.EventType.Win, Game.EventType.Win)
	logEvent(event, true)
	return event

func logLoss():
	var event = createEvent(null, Game.EventType.Loss, Game.EventType.Loss)
	logEvent(event, true)
	return event

func moveArrowTo(line: CombatLogLine, ensureVisibility: bool):
	activeLine = line
	if ensureVisibility:
		if activeLine.visible:
			scrollContainer.ensure_control_visible(activeLine)

func showArrow():
	lineArrow.show()

func hideArrow():
	lineArrow.hide()

func onButtonPressed():
	Expedition.show_combat_log()
	return

func open() -> void :
	Expedition.show_combat_log()
	return

func close() -> void :
	load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").close(self)

func onScrollbarVisibilityChanged():
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").onScrollbarVisibilityChanged(self)

func canDrag():
	return super.canDrag() and not scrollContainer.scrollbarHovered

func updateIdle() -> void :
	load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").updateIdle(self)

func onVerticalResizeButtonDown():
	super.onVerticalResizeButtonDown()
	hideArrow()

func _on_CloseButton_pressed() -> void :
	close()

func onHorizontalResizeButtonDown() -> void :
	super.onHorizontalResizeButtonDown()
	hideArrow()

func getNumEvents() -> int:
	return events.size()

func getTimeOfEvent(_eventNum: int) -> float:
	if _eventNum < 0: return 0.0
	return events[_eventNum].timestamp

func getCombatDuration() -> float:
	return events.back().timestamp

func getLastEventNum() -> int:
	return eventNum

func onPlayerToggled(pressed: bool):

	showPlayerEvents = pressed
	onFilterChanged()

func onOpponentToggled(pressed: bool):
	showOpponentEvents = pressed
	onFilterChanged()

func isLineVisible(line: CombatLogLine) -> bool:
	if (line.getType() == Game.EventType.Activation and
		activationsState == ActivationsState.Hide):
			return false

	return true

func isLineMinimized(line: CombatLogLine) -> bool:
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").isLineMinimized(self, line)

func getLastVisibleLine() -> CombatLogLine:
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").getLastVisibleLine(self)

func getNextVisibleLine() -> CombatLogLine:
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").getNextVisibleLine(self)

func getPreviousVisibleLine() -> CombatLogLine:
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").getPreviousVisibleLine(self)

var activeLineYBeforeFilterChange: float

func onFilterChanged():
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").onFilterChanged(self)

func updateScroll():
	lineArrow.show()
	var newLinePos = activeLine.global_position.y
	var diff = newLinePos - activeLineYBeforeFilterChange
	scrollContainer.scroll_vertical += diff

func onSearchTextChanged(newText):
	searchTerm = newText
	onFilterChanged()

func getStylebox(player: bool, state: int, faded: bool):
	var stylebox
	if player:
		stylebox = playerStyleboxes[state]
	else:
		stylebox = opponentStyleboxes[state]

	if faded:
		return fadedStyleboxes[stylebox]
	else:
		return stylebox

func setActivationState(newState: int):
	activationsState = newState
	onFilterChanged()

func snapshotGlobalStat(stat: int, newValue):
	globalStatHistories[stat].addValue(eventNum, newValue)

func _input(event):
	if InputBlocker.isActive(): return
	super._input(event)
	if (Game.fightEnded and not replayingCombat and activeLine != null and
		Util.isKeyOrJoyButton(event)):

		if Util.isActionPressed_event(event, "shift_down"):
			var nextLine = getNextVisibleLine()
			onLineHovered(nextLine)
			scrollTimer.start(0.2)

		elif Util.isActionPressed_event(event, "shift_up"):
			var nextLine = getPreviousVisibleLine()
			onLineHovered(nextLine)
			scrollTimer.start(0.2)

		elif Util.isActionReleased_event(event, "shift_down"):
			if not Util.isActionPressed("shift_up"):
				scrollTimer.stop()

		elif Util.isActionReleased_event(event, "shift_up"):
			if not Util.isActionPressed("shift_down"):
				scrollTimer.stop()

func scrollTimerTimeout():
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").scrollTimerTimeout(self)

func onGetRects():
	return load("res://Runtime/Behavior/Features/Core/CombatLogBehavior.gd").onGetRects(self)

func onCursorWarp():
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").onCursorWarp(self)

func logElectricalCharge(emitterEvent: CombatEvent, duration: float, cells: Array):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").logElectricalCharge(self, emitterEvent, duration, cells)

func replayElectricalCharges(event: CombatEvent):
	return load("res://Runtime/Behavior/Core/CombatLogBehavior.gd").replayElectricalCharges(self, event)

class ElectricalChargeData:

	var emitterEvent: CombatEvent
	var duration: float

	var cells: Array

	func _init(event: CombatEvent, dur: float, _cells: Array):
		emitterEvent = event
		duration = dur

		cells = _cells

	func getProgressAt(event: CombatEvent):

		if emitterEvent.id > event.id:
			return - 1

		if emitterEvent.timestamp + duration < event.timestamp:
			return - 2

		var timePassed = event.timestamp - emitterEvent.timestamp
		return timePassed
