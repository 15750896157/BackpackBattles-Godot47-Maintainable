extends ResizableControl

const damageMeterEntry = preload("res://Interface/DamageMeter/DamageMeterEntry.tscn")
const totalScene = preload("res://Interface/DamageMeter/DamageMeterTotal.tscn")
const stackChangeSectionLabel = preload("res://Interface/DamageMeter/StackChangeSectionLabel.tscn")
const plotScene = preload("res://Interface/DamageMeter/DamageMeterPlot.tscn")

const submetricNames_buff = ["UI_DamageMeter_Gained", "UI_DamageMeter_Removed", "UI_DamageMeter_Used"]
const submetricNames_debuff = ["UI_DamageMeter_Inflicted", "UI_DamageMeter_Cleansed", "UI_DamageMeter_Used"]
const submetricNames_stamina = ["UI_DamageMeter_Used", "UI_DamageMeter_Gained", "UI_DamageMeter_Removed"]

@export var player: bool
var isOpen = false

@onready var header = $Label
@onready var scrollContainer = $ScrollContainer
@onready var vboxContainer = $ScrollContainer/VBoxContainer
@onready var openButton = $OpenButton
@onready var icon = $Icon
@onready var metricList: ItemListButton = $Node2D/MetricList
@onready var verticalResizeButton = $VerticalResizeButton

var itemToEntry: Dictionary
var visibleMetric = Game.ItemMetrics.Damage
var currentEvent = null
var plots = []
var plotToEntry: Dictionary

func _ready() -> void :
	super._ready()
	close()
	add_to_group("Localized")
	Game.connect("returned_to_title", Callable(self, "reset"))
	Game.connect("shop_opened", Callable(self, "reset"))
	metricList.connect("list_opened", Callable(self, "onMetricListOpened"))
	metricList.connect("list_closed", Callable(self, "onMetricListClosed"))
	updateMetricList()
	scrollContainer.onClose()

func canDrag():
	return super.canDrag() and not scrollContainer.scrollbarHovered

func updateLocale():
	updateMetricList()

var metricKeys = {
	Game.ItemMetrics.Damage: "UI_DamageMeter_Player",
	Game.ItemMetrics.Heal: "UI_DamageMeter_Heal",
	Game.ItemMetrics.Stamina: "Stamina_NAME",
	Game.ItemMetrics.Overheal: "UI_DamageMeter_Overheal",
	Game.ItemMetrics.Misses: "UI_DamageMeter_Misses",
	Game.ItemMetrics.Activations: "UI_DamageMeter_Activations",
	Game.ItemMetrics.DamageBlocked: "UI_DamageMeter_DamageBlocked",
	Game.ItemMetrics.MaxHealth: "UI_DamageMeter_MaxHealth",
	Game.ItemMetrics.OutOfStamina: "UI_DamageMeter_OutOfStamina"
}

var metricIndices = [
	Game.ItemMetrics.Damage,
	Game.ItemMetrics.Heal,
	Game.ItemMetrics.Stamina,
	Game.ItemMetrics.Activations,
	Game.ItemMetrics.Block,
	Game.ItemMetrics.Lucky,
	Game.ItemMetrics.Regeneration,
	Game.ItemMetrics.Vampirism,
	Game.ItemMetrics.Spikes,
	Game.ItemMetrics.Mana,
	Game.ItemMetrics.Empower,
	Game.ItemMetrics.Heat,
	Game.ItemMetrics.Poison,
	Game.ItemMetrics.Blind,
	Game.ItemMetrics.Cold
]

@onready var metricIndicesReversed = Util.arrayAsIndexDict(metricIndices)
@onready var stacksMetricOffset = Game.EventType.Block - metricIndicesReversed[Game.ItemMetrics.Block]

func updateMetricList():
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").updateMetricList(self)

func onMetricListOpened():
	verticalResizeButton.hide()

func onMetricListClosed():
	verticalResizeButton.show()

func reset():
	currentEvent = null

func clear():
	for child in vboxContainer.get_children():
		if not child is DamageMeterPlot:
			ObjectPool.returnInstance(child)

	itemToEntry.clear()
	plotToEntry.clear()

func setTime(time):
	for plot in plots:
		plot.setHoveredTime(time)

func onMetricSelected(index, text):
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").onMetricSelected(self, index, text)

func clearPlots():
	for plot in plots:
		plot.returnToObjectPool()
	plots.clear()

func createPlot():
	clearPlots()
	if Game.combatLog.loggingFinished:
		updatePlot()

	var playerId = 0 if player else 1
	updateMeter(currentEvent, Game.combatLog.statLoggers[playerId])

func updatePlot():
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").updatePlot(self)

func getSubMetrics():
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").getSubMetrics(self)

func metricToEventType(metric: int) -> int:
	return Game.EventType.Block + metric - Game.ItemMetrics.Block

func updateMeter(event, statLogger: CombatStatLogger):
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").updateMeter(self, event, statLogger)

func addMeter(dmgMeter: Dictionary, combatTime: float, plot = null):
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").addMeter(self, dmgMeter, combatTime, plot)

func highlightSource(source):
	if source in itemToEntry:
		for entry in itemToEntry[source]:
			entry.highlight()

func unhighlightSource(source):
	if source in itemToEntry:
		for entry in itemToEntry[source]:
			entry.unhighlight()

func isVisible():
	return isOpen and Game.combatLog.visible

func onShow():
	var playerId = 0 if player else 1
	updateMeter(currentEvent, Game.combatLog.statLoggers[playerId])

func open():
	Expedition.show_combat_log()
	return

func close():
	return load("res://Runtime/Behavior/Interface/DamageMeter/DamageMeterBehavior.gd").close(self)

func _on_OpenButton_pressed() -> void :
	if isOpen:
		close()
	else:
		open()
