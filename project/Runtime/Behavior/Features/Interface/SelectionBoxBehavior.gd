extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/SelectionBox.gd")

static func startSelecting(subject: Receiver):
	subject.set_process(true)
	subject.collisionShape.disabled = false
	subject.area.monitoring = true
	subject.boxVisual.show()
	Game.SELECTING = true
	subject.startFrame = Util.getFrameCounter_process()
	InputBlocker.disableAllControls(InputBlocker.Source.BoxSelect, Game.mainNode)

static func findAndPickCloseItem(subject: Receiver, radius):

	var closeItem = subject.findCloseItem(radius)
	if closeItem != null and closeItem.isPickingPossible():
		subject.end()

		Game.disableTooltipsFor(6)
		closeItem.gainFocus()
		closeItem.pickup()
		return true
	return false

static func findCloseItem(subject: Receiver, radius):
	subject.grabbingShape.radius = radius
	var spaceState = subject.get_world_2d().get_direct_space_state()
	subject.spaceStateQuery.transform = Transform2D(0, subject.get_global_mouse_position())
	var restInfo = spaceState.get_rest_info(subject.spaceStateQuery)
	if not restInfo.is_empty():
		var object = instance_from_id(restInfo.collider_id)
		if object is Item:
			return object

	return null

static func canPickFromInventory(subject: Receiver, item) -> bool:
	if subject.withoutBags:
		return ( not item.isBag() and
			item.ownerType == item.Owner.PlayerInventory and
			item.canBeDraggedWithBag())
	else:
		return (item.isBag() and
			item.ownerType == item.Owner.PlayerInventory and
			item.canBeDraggedWithBag())

static func canPickFromStorage(subject: Receiver, item) -> bool:
	if not item.visible: return false

	if item.ownerType == item.Owner.PlayerStorageBox:
		if item.isBag():
			return Game.inventoryEditMode != Game.InventoryEditMode.ItemLayer
		else:
			return Game.inventoryEditMode != Game.InventoryEditMode.BagLayer

	return false

static func onItemAreaExited(subject: Receiver, itemArea):
	if not Game.SELECTING: return
	var item = itemArea.get_parent()
	if subject.canPickFromInventory(item):
		subject.selectedInventoryItems.erase(item)

		item.resetBright()
	elif subject.canPickFromStorage(item):
		subject.selectedStorageItems.erase(item)

static func end(subject: Receiver):
	if not Game.SELECTING: return
	subject.set_process(false)
	subject.boxVisual.hide()
	subject.selectedInventoryItems.clear()
	subject.selectedStorageItems.clear()
	Game.SELECTING = false
	subject.collisionShape.disabled = true

	subject.area.position.x = - 100000
	InputBlocker.restoreAllControls(InputBlocker.Source.BoxSelect)
