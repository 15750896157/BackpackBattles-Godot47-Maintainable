extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Inventory.gd")

static func isInventoryCell(subject: Receiver, cell):
	return (cell.x >= 0 and cell.x < subject.inventorySize.x and
			cell.y >= 0 and cell.y < subject.inventorySize.y)

static func isTilePotentialSpace(subject: Receiver, tile):
	return (tile == subject.Tile.PotentialSpace or
			tile == subject.Tile.PotentialSpaceHovered or
			tile == subject.Tile.HoveredOutside or
			tile == subject.Tile.HoveredOK_Bag or
			tile == subject.Tile.HoveredFail_Bag)

static func canAddBag(subject: Receiver, bag, checkCollisions):
	if bag.pve_is_view(): return Expedition.bridge.preview(bag).ok
	var extensionPoints = bag.getExtensionPoints()
	var cells = subject.getCellsForGlobalPositions(extensionPoints)
	if checkCollisions:
		return subject.allCellsPotentialSpace(cells)
	else:
		for cell in cells:
			if not subject.isInventoryCell(cell):
				return false
		return true

static func getAffectedPoints(subject: Receiver, item, color):
	var points = []
	var tileToCells = subject.getAffectedCells(item, color)[subject.AffectedTile.CanAffect + color]
	for cell in tileToCells:
		points.push_back(subject.aboveTilemap.to_global(LegacyGrid.cell_origin(subject.aboveTilemap, cell)) + subject.halfCellSize)
	return points

static func clearItemCells(subject: Receiver, item: Item):
	for cell in item.occupiedCells:
		if item.isBag():
			if subject.bagCells.get(cell, null) == item:
				subject.bagCells.erase(cell)
		else:
			if subject.filledCells.get(cell, null) == item:
				subject.filledCells.erase(cell)

	subject.recalculateTilemap()

static func removeItem(subject: Receiver, item: Item):
	if item.pve_is_view():
		subject.clearItemCells(item)
		subject.items.erase(item)
		item.removeFromInventory()
		return
	subject.clearItemCells(item)
	subject.items.erase(item)
	item.removeFromInventory()
	Game.onInventoryChanged()
	subject.emit_signal("item_removed", item)

static func findPlaceForItem(subject: Receiver, item):
	var freeCells = subject.getFreeBagCells()
	for faceDir in [Item.FaceDirection.UP, Item.FaceDirection.RIGHT]:
		for topleftCell in freeCells:
			subject.orientItem(item, topleftCell, faceDir)
			if subject.canAddItem(item):
				return topleftCell
	return null

static func getItemsInCells(subject: Receiver, cells) -> Array:
	var itemsInCells = []
	for cell in cells:
		if subject.filledCells.has(cell):
			var item = subject.filledCells[cell]

			if not item in itemsInCells and item.placed:
				itemsInCells.push_back(item)

	return itemsInCells

static func getBagsInCells(subject: Receiver, cells):
	var bags = []
	for cell in cells:
		if subject.bagCells.has(cell):
			var bag = subject.bagCells[cell]
			if not bag in bags:
				bags.push_back(bag)

	return bags

static func deleteItems(subject: Receiver):
	var itemList = subject.items.duplicate()
	subject.items.clear()

	for item in itemList:
		item.discard()

	for cell in subject.filledCells:
		subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Empty, Vector2i.ZERO, 0)
	subject.filledCells.clear()

	subject.bagCells.clear()

	subject.cleanUp()

static func orientItem(subject: Receiver, item, topLeftCell, faceDirection) -> void :
	item.scale = Vector2.ONE
	item.setFaceDirectionInstant(faceDirection)

	var curPos = item.getTopLeftGlobal()
	var targetPos = subject.tilemap.to_global(LegacyGrid.cell_origin(subject.tilemap, topLeftCell))
	item.global_translate(targetPos - curPos)

static func orientAndAddItem(subject: Receiver, item, topLeftCell, faceDirection, checkCollision):
	item.ownerType = Item.Owner.PlayerInventory
	subject.itemNode.add_child(item)
	subject.orientItem(item, topLeftCell, faceDirection)

	if checkCollision and not subject.canAddItem(item):
		item.pushToStorage(Game.STORAGEBOX.center)
	else:
		subject.addItemByTopLeft(item, topLeftCell)

static func getLeftBorder(subject: Receiver):
	var leftMostCell = 10
	for cell in subject.bagCells:
		if cell.x < leftMostCell:
			leftMostCell = cell.x
	return subject.tilemap.global_position.x + LegacyGrid.cell_origin(subject.tilemap, Vector2(leftMostCell, 0)).x

static func pve_cycle_zone(subject: Receiver, direction: int):
	var zones = ["inventory", "shop", "storage"]
	subject.pve_set_zone(zones[posmod(zones.find(subject.pve_zone) + direction, zones.size())])
