extends Node2D

signal toggled

const entryScene = preload("res://Interface/GridStorageEntry.tscn")
const itemScale = {
	3: 1.0,
	4: 0.85,
	5: 0.7,
	6: 0.7,
	7: 0.7
}

@onready var scrollContainer = $ScrollContainer
@onready var gridContainer = $ScrollContainer/GridContainer
@onready var defaultZIndex = z_index

var rebuildQueued: bool
var newItems: Dictionary
var descriptorToEntry: Dictionary

func _ready():
	return load("res://Runtime/Behavior/Interface/GridStorageBehavior.gd")._ready(self)

func onItemAddedToStorage(item):
	if visible:
		item.onAddedToGridStorage()

	newItems[item.descriptor] = true
	rebuild()

func onItemRemovedFromStorage(item):
	if visible:
		item.onRemovedFromGridStorage()

	rebuild()

func onStorageCleared():
	rebuild()

func onUndoStateChanged():
	rebuild()

func rebuild():
	if not rebuildQueued:
		rebuildQueued = true
		call_deferred("actuallyRebuild")

func clear():
	descriptorToEntry.clear()
	for entry in gridContainer.get_children():
		entry.returnToObjectPool()

func actuallyRebuild():
	return load("res://Runtime/Behavior/Interface/GridStorageBehavior.gd").actuallyRebuild(self)

func _unhandled_input(event):
	if Util.isActionPressed_event(event, "toggle_grid_storage"):
		if visible:
			close()
		else:
			open()

func open():
	show()
	for item in Game.STORAGEBOX.getItemsAndGems():
		item.onAddedToGridStorage()
	rebuild()
	scrollContainer.onOpen()
	emit_signal("toggled")

func close():
	hide()
	for item in Game.STORAGEBOX.getItemsAndGems():
		item.onRemovedFromGridStorage()
	clear()
	scrollContainer.onClose()
	emit_signal("toggled")

func getScore(descriptor) -> float:
	return load("res://Runtime/Behavior/Interface/GridStorageBehavior.gd").getScore(self, descriptor)

func onEditModeChanged():
	rebuild()

func getProxy(forItem):
	if forItem.descriptor in descriptorToEntry:
		return descriptorToEntry[forItem.descriptor].item
	else:
		return null

func onReturningToTitle():
	z_index = 10

func onShopEntered():
	z_index = defaultZIndex

func onZoomed(amount):
	var colums = clamp(gridContainer.columns + amount, 3, 7)
	if gridContainer.columns != colums:
		gridContainer.columns = colums
		rebuild()
