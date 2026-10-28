extends Node2D

signal state_changed
signal state_added

const undoSound = preload("res://Assets/Sound/Switch.wav")
const MAX_STATES = 100

var states = []
var curStateIndex = - 1
var snapshotQueued = false
var manualSnapshots = []
var tween

@onready var label = $Label
@onready var animation = $AnimationPlayer
@onready var leftArrow = $LeftArrow
@onready var rightArrow = $RightArrow

func _ready():
	call_deferred("ready_deferred")
	manualSnapshots.resize(10)
	label.modulate.a = 0
	leftArrow.modulate.a = 0
	rightArrow.modulate.a = 0

func ready_deferred():
	return await load("res://Runtime/Behavior/Utility/UndoStackBehavior.gd").ready_deferred(self)

func _unhandled_input(event):
	return load("res://Runtime/Behavior/Utility/UndoStackBehavior.gd")._unhandled_input(self, event)

func onItemDropped(item, _dropRes):
	if item.hasSameOrientationAsPickup():

		return
	queueSnapshot()

func onItemCrafted(_itemDescriptor):
	queueSnapshot()

func onInventoryShifted():
	queueSnapshot()

func onPushedAllToStorage():
	queueSnapshot()

func onShopOpened():
	queueSnapshot()

func queueSnapshot():
	return

func makeSnapshot():
	snapshotQueued = false
	return

func clear():
	states.clear()
	curStateIndex = - 1
	manualSnapshots.fill(null)

func canUndo() -> bool:
	return Expedition.active and Expedition.flow.screen_state == "SHOP_PREPARE" and not Expedition.flow.edit_history.undo_stack.is_empty()

func undo():
	if canUndo():
		Expedition.perform(Expedition.flow.edit("undo"))
		emit_signal("state_changed")
	return

func canRedo() -> bool:
	return Expedition.active and Expedition.flow.screen_state == "SHOP_PREPARE" and not Expedition.flow.edit_history.redo_stack.is_empty()

func redo():
	if canRedo():
		Expedition.perform(Expedition.flow.edit("redo"))
		emit_signal("state_changed")
	return

func makeManualSnapshot(index):
	return

func restoreSnapshop(index):
	return

func showLabel(undo: bool):
	return load("res://Runtime/Behavior/Utility/UndoStackBehavior.gd").showLabel(self, undo)

func showLabelManual(slot, restore: bool):
	return load("res://Runtime/Behavior/Utility/UndoStackBehavior.gd").showLabelManual(self, slot, restore)

class InventoryState:

	var storageItems: Dictionary
	var bags: Dictionary
	var items: Dictionary
	var socketedGems: Dictionary
	var editMode: int

	func getTuple(item):
		return [item.getTopLeftCell(), item.getFaceDirection()]

	func _init():
		editMode = Game.inventoryEditMode
		var inv = Game.PLAYER.INVENTORY
		for item in inv.getItems():
			if item.isBag():
				if not CustomRules.getCannotPickBags():
					bags[item] = getTuple(item)
			else:
				items[item] = getTuple(item)

		for item in Game.STORAGEBOX.getItems():
			storageItems[item] = item.get_global_transform()

		for item in inv.getItems() + Game.STORAGEBOX.getItems():
			var socketI = 0
			for gem in item.getGems():
				if gem != null:
					socketedGems[gem] = [item, socketI, gem.getFaceDirection()]
				socketI += 1

	func printState():
		print("STORAGE")
		for item in storageItems:
			print(item.getName(), " ", storageItems[item])

		print("BAGS")
		for item in bags:
			print(item.getName(), " ", bags[item])

		print("INVENTORY")
		for item in items:
			print(item.getName(), " ", items[item])

		print("GEMS")
		for item in socketedGems:
			print(item.getName(), " ", socketedGems[item])

	func exists(item) -> bool:
		return is_instance_valid(item) and not item.sold

	func restore():
		Game.setInventoryEditMode(editMode)
		var leftOver = {}
		var inv = Game.PLAYER.INVENTORY
		var invItems = inv.getItems().duplicate()

		for item in invItems:
			if item.isBag() and CustomRules.getCannotPickBags():
				continue

			item.onRestoreSnapshot()
			inv.removeItem(item)
			leftOver[item] = true

			for gem in item.getGemsNoNull():
				gem.unsocket()
				leftOver[gem] = true

		for item in Game.STORAGEBOX.getItems():
			item.onRestoreSnapshot()
			for gem in item.getGemsNoNull():
				gem.unsocket()
				leftOver[gem] = true

		for item in bags:
			if not exists(item):
				continue

			var topLeftCellPos = bags[item][0]
			var faceDirection = bags[item][1]

			if item.ownerType == Item.Owner.PlayerStorageBox:
				item.removeFromStorage()

			inv.orientItem(item, topLeftCellPos, faceDirection)
			if inv.canAddItemOrBag(item):
				inv.addItemByTopLeft(item, topLeftCellPos)
				leftOver.erase(item)

		for item in items:
			if not exists(item):
				continue

			var topLeftCellPos = items[item][0]
			var faceDirection = items[item][1]

			if item.ownerType == Item.Owner.PlayerStorageBox:
				item.removeFromStorage()
				item.ownerType = Item.Owner.Undefined

			if not item.visible:
				item.show()
				Game.setItemEditMode(item, false)

			item.scale = Vector2.ONE
			inv.orientItem(item, topLeftCellPos, faceDirection)

			if inv.canAddItemOrBag(item) or editMode != Game.InventoryEditMode.Default:
				inv.addItemByTopLeft(item, topLeftCellPos)
				leftOver.erase(item)
			else:

				leftOver[item] = true

		for gem in socketedGems:
			if not exists(gem):
				continue

			var item = socketedGems[gem][0]
			if not exists(item):
				continue

			var slotI = socketedGems[gem][1]
			var faceDir = socketedGems[gem][2]

			if gem.ownerType == Item.Owner.PlayerStorageBox:
				gem.removeFromStorage()
			gem.get_parent().remove_child(gem)
			item.setGem(slotI, gem)
			leftOver.erase(gem)

			if item.ownerType == Item.Owner.PlayerInventory:
				gem.onRemovedFromGridStorage()

		for item in storageItems:
			if not exists(item):
				continue

			if item.isBag() and CustomRules.getCannotPickBags():
				continue

			var transf: Transform2D = storageItems[item]
			if Game.STORAGEBOX.hasPosition(transf.get_origin()):
				leftOver.erase(item)
				item.set_global_transform(transf)
				if item.ownerType != Item.Owner.PlayerStorageBox:
					item.addToStorageBox(false, false, true)
			else:
				leftOver[item] = true

		var itemI = 0
		for item in leftOver:

			if item.ownerType == Item.Owner.PlayerStorageBox:
				item.global_position = Game.STORAGEBOX.center
				item.moveToFreeSpaceInStorage()
			else:
				var pos = Game.STORAGEBOX.getSuggestedPosition(itemI)
				item.global_position = pos
				item.addToStorageBox(false, false, true, pos)
				itemI += 1
