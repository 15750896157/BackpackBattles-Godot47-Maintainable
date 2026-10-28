extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func placeGeneratedItem(subject: Receiver, item, candidateCells):
	var foundSpace = false
	for cell in candidateCells:
		if subject.inventory.isCellEmpty(cell):
			subject.inventory.orientAndAddItem(item, cell, subject.FaceDirection.UP)

			foundSpace = true
			item.moveTo(subject.global_position, item.global_position, 0.2)
			item.locked = true
			if Game.itemsAreFusing:
				Util.callDelayed(item, "unlockCombining", subject.PRE_FUSE_DUR, [false])
			else:
				item.call_deferred("unlockCombining", false)
			break

	if not foundSpace:
		Game.playerNode.add_child(item)
		item.global_position = subject.global_position
		item.pushToStorage(Game.STORAGEBOX.center + Util.randInBox(100, 100))

static func shift(subject: Receiver, direction: Vector2):
	if subject.isBag():

		if Game.inventoryEditMode != Game.InventoryEditMode.Default:
			CraftingManager.itemShifted(subject)

		if Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer:
			return
	else:
		if Game.inventoryEditMode == Game.InventoryEditMode.BagLayer:
			return

	subject.finishMoveback()
	subject.resetSprite()

	var pixelShift = direction * subject.inventory.cellSize

	if subject.dragged:
		subject.pickupPosition += pixelShift
	else:
		subject.position += pixelShift

	for i in subject.occupiedCells.size():
		subject.occupiedCells[i] = subject.occupiedCells[i] + direction

	subject.cacheAffectedCells()

	for gem in subject.getGemsNoNull():
		gem.shift(direction)
