extends RefCounted
class_name Buff

var type: int
var isBuff: bool
var character: Node2D
var current: int = 0
var permanentStacks: int = 0
var counter: Node2D

var resistChancePercent: float = 0.0
var resistStacks: int = 0

var reflectChancePercent: float = 0.0

var cleanseProtectionChancePercent: float = 0.0

var signalName: String
var timer: Timer
var temporaryStacks: Array
var nextTemporaryTimeout: int
var MAX_STACKS: int

func init(_type, _character, _counter = null, _signalName = ""):
	return load("res://Runtime/Behavior/Core/BuffBehavior.gd").init(self, _type, _character, _counter, _signalName)

func getStacks():
	return current

func setStacks(amount: int):
	current = amount
	counter.updateHud(current)

func reset():
	setStacks(0)
	resistStacks = 0
	resistChancePercent = 0.0
	cleanseProtectionChancePercent = 0.0
	reflectChancePercent = 0.0

func changeResistChance(chance):
	resistChancePercent += chance

func changeResistStacks(amount):
	resistStacks = max(0, resistStacks + amount)

func changeCleanseProtectionChance(chance):
	cleanseProtectionChancePercent += chance

func changeReflectChance(amount):
	reflectChancePercent += amount

func gainStacks(amount: int, item = null, triggerEvent = null,
	reflect: bool = false):

	return gainTemporary(amount, - 1, item, triggerEvent, reflect)

func gainTemporary(amount: int, duration: float, item = null,
	triggerEvent = null, reflect: bool = false):
	return load("res://Runtime/Behavior/Core/BuffBehavior.gd").gainTemporary(self, amount, duration, item, triggerEvent, reflect)

func loseStacks(amount: int, item = null, triggerEvent = null, used = false):
	return load("res://Runtime/Behavior/Core/BuffBehavior.gd").loseStacks(self, amount, item, triggerEvent, used)

func changeCurrentLogShowLabel(isTimeout: bool, amount: int,
	item = null, triggerEvent = null, used: bool = false):
	return load("res://Runtime/Behavior/Core/BuffBehavior.gd").changeCurrentLogShowLabel(self, isTimeout, amount, item, triggerEvent, used)

func onTimeout():
	return load("res://Runtime/Behavior/Core/BuffBehavior.gd").onTimeout(self)

func combatEnd():
	timer.stop()
	temporaryStacks.clear()

class TemporaryStacks extends RefCounted:
	var amount: int
	var timeout: float
	var item: Item

	func _init(_amount, _timeout, _item = null):
		amount = _amount
		timeout = _timeout
		item = _item
