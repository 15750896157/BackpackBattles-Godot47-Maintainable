extends Area2D

const RESETTIME: = 5

@onready var indicatorTimer = $IndicatorTimer

var ticks = 0
var exitTimes: Dictionary
var offscreenIndicatorActive = false

func _ready():
	Game.connect("switch_to_shop", Callable(self, "onSwitchToShop"))
	call_deferred("ready_deferred")

func ready_deferred():
	Game.gridStorage.connect("toggled", Callable(self, "updateIndicatorVisibility"))

func onSwitchToShop():
	cleanUp()

func checkBodies():
	if Game.state == Game.State.Shop:
		ticks += 1
		cleanUp()

func cleanUp():
	return load("res://Runtime/Behavior/Utility/ItemBoundCheckerBehavior.gd").cleanUp(self)

func onBodyEntered(body):
	if body in exitTimes:
		exitTimes.erase(body)
		disconnectItem(body)
		updateIndicator()

func onBodyExited(body):
	return load("res://Runtime/Behavior/Utility/ItemBoundCheckerBehavior.gd").onBodyExited(self, body)

func onItemAddedToInventory(item):
	exitTimes.erase(item)
	cleanUp()
	disconnectItem(item)

func onItemPickedUp(item):
	exitTimes.erase(item)
	cleanUp()
	disconnectItem(item)

func disconnectItem(item):
	Util.tryDisconnect(item, "added_to_inventory", self, "onItemAddedToInventory")
	Util.tryDisconnect(item, "picked_up", self, "onItemPickedUp")

func updateIndicator():

	if exitTimes.size() == 0:
		indicatorTimer.stop()
		offscreenIndicatorActive = false
		updateIndicatorVisibility()

func updateIndicatorVisibility():
	if Game.gridStorage.visible:
		Game.shopSceneNode.itemOffScreenIndicator.visible = false
	else:
		Game.shopSceneNode.itemOffScreenIndicator.visible = offscreenIndicatorActive

func onIndicatorTimeout():
	offscreenIndicatorActive = true
	updateIndicatorVisibility()

func onIndicatorPressed():
	return load("res://Runtime/Behavior/Utility/ItemBoundCheckerBehavior.gd").onIndicatorPressed(self)

