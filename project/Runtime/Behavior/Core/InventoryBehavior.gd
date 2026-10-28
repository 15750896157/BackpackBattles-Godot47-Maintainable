extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Inventory.gd")

static func _ready(subject: Receiver) -> void :
	Game.connect("item_dropped", Callable(subject, "onItemDropped"))

	subject.cleanUp()

	var upcells = []
	for x in subject.inventorySize.x:
		upcells.push_back(Vector2(x, 0))
	subject.borderCells[Vector2.UP] = upcells

	var downcells = []
	for x in subject.inventorySize.x:
		downcells.push_back(Vector2(x, subject.inventorySize.y - 1))
	subject.borderCells[Vector2.DOWN] = downcells

	var leftcells = []
	for y in subject.inventorySize.y:
		leftcells.push_back(Vector2(0, y))
	subject.borderCells[Vector2.LEFT] = leftcells

	var rightcells = []
	for y in subject.inventorySize.y:
		rightcells.push_back(Vector2(subject.inventorySize.x - 1, y))
	subject.borderCells[Vector2.RIGHT] = rightcells

static func actuallyRecalculateTilemap(subject: Receiver):
	subject.recalculateQueued = false
	for cell in subject.inventoryCells:
		if cell in subject.filledCells:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Filled, Vector2i.ZERO, 0)
		elif cell in subject.bagCells:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Empty, Vector2i.ZERO, 0)
		else:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpace, Vector2i.ZERO, 0)

static func cleanUp(subject: Receiver):
	subject.tilemap.modulate.a = 0.7

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.PotentialSpaceHovered):
		if (Game.inventoryEditMode == Game.InventoryEditMode.BagLayer and
			cell in subject.filledCells):
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Filled, Vector2i.ZERO, 0)
		else:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpace, Vector2i.ZERO, 0)

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.HoveredOutside):
		subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpace, Vector2i.ZERO, 0)

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.HoveredOK):
		if (Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer and
			not cell in subject.bagCells):
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpace, Vector2i.ZERO, 0)
		else:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Empty, Vector2i.ZERO, 0)

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.HoveredFail):
		subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Empty, Vector2i.ZERO, 0)

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.Collision):
		subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Filled, Vector2i.ZERO, 0)

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.HoveredOK_Bag):
		subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpace, Vector2i.ZERO, 0)

	for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.HoveredFail_Bag):
		if cell in subject.filledCells:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Filled, Vector2i.ZERO, 0)
		elif cell in subject.bagCells:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Empty, Vector2i.ZERO, 0)
		else:
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpace, Vector2i.ZERO, 0)
	subject.aboveTilemap.clear()

static func canAddItem(subject: Receiver, item: Item, checkCollision, checkBags):
	if item.pve_is_view(): return Expedition.bridge.preview(item).ok
	var insideCells = subject.getPlacableCells()
	var collisionPoints = item.getCollisionPoints()

	var cells = subject.getCellsForGlobalPositions(collisionPoints)

	if checkBags:
		for cell in cells:
			if ( not cell in insideCells or
				(checkCollision and subject.filledCells.get(cell, null))):
				return false
	else:
		for cell in cells:
			if not subject.isInventoryCell(cell):
				return false

	return true

static func previewItem(subject: Receiver, item):
	if item.isBag():
		for cell in LegacyGrid.used_cells_by_id(subject.tilemap, subject.Tile.PotentialSpace):
			subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.PotentialSpaceHovered, Vector2i.ZERO, 0)

	subject.tilemap.modulate.a = 1.0

	var collisionPoints
	if item.isBag():
		collisionPoints = item.getExtensionPoints()
	else:
		collisionPoints = item.getCollisionPoints()
	var cells = subject.getCellsForGlobalPositions(collisionPoints)

	subject.clearHoveredCache()
	for cell in cells:
		subject.curHovered[cell] = true

	if item.isBag():
		if subject.canAddBag(item):
			for cell in cells:
				subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.HoveredOK_Bag, Vector2i.ZERO, 0)
			return

		for cell in cells:
			if subject.isInventoryCell(cell):

				subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.HoveredFail_Bag, Vector2i.ZERO, 0)

	else:
		if subject.canAddItem(item):
			for cell in cells:
				subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.HoveredOK, Vector2i.ZERO, 0)
			return

		for cell in cells:
			if subject.tilemap.get_cell_source_id(0, Vector2i(cell)) == subject.Tile.PotentialSpace:
				subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.HoveredOutside, Vector2i.ZERO, 0)
			elif subject.tilemap.get_cell_source_id(0, Vector2i(cell)) == subject.Tile.Filled:
				subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.Collision, Vector2i.ZERO, 0)
			elif subject.tilemap.get_cell_source_id(0, Vector2i(cell)) == subject.Tile.Empty:
				subject.tilemap.set_cell(0, Vector2i(cell), subject.Tile.HoveredFail, Vector2i.ZERO, 0)

static func previewAffectedCells(subject: Receiver, item):

	var colors = Item.Affected.values()
	if item.isBag():
		colors = [Item.Affected.Primary]
	else:
		colors = Item.Affected.values()

	for color in colors:
		var tileToCells = subject.getAffectedCells(item, color)
		for tile in tileToCells:
			for cell in tileToCells[tile]:
				subject.aboveTilemap.set_cell(0, Vector2i(cell), tile, Vector2i.ZERO, 0)

static func getAffectedCells(subject: Receiver, item, color: int) -> Dictionary:
	if item.pve_is_view(): return Expedition.bridge.affected_cells(item, color, subject)
	var insideCells = subject.getPlacableCells()

	subject.affectedItemsChecked.clear()
	var tileToCells = {
		subject.AffectedTile.CanAffect + color: [],
		subject.AffectedTile.CannotAffect + color: [],
		subject.AffectedTile.AffectsInside: []
	}

	var affectedCells: Array

	if item.isBag():
		affectedCells = subject.getCellsForGlobalPositions(item.getExtensionPoints())
	else:
		affectedCells = subject.getCellsForGlobalPositions(item.getAffectedPoints(color))

	if affectedCells.is_empty(): return tileToCells

	affectedCells.sort_custom(Callable(subject.CellSorter, "sort"))
	var itemsChecked = []
	for cell in affectedCells:
		if cell in insideCells:

			var canAffect: bool
			var itemInCell = subject.filledCells.get(cell, null)
			if itemInCell:
				if itemsChecked.has(itemInCell) and color != Item.Affected.Lightning:
					canAffect = false
				else:
					if item.isBag():
						canAffect = item.canApplyEffect(itemInCell)
					else:
						canAffect = item.canAffect_color(itemInCell, color)
						if item.isAffectingDistinct(color):
							canAffect = canAffect and subject.isDistinct(itemInCell)
					itemsChecked.push_back(itemInCell)
					if canAffect:
						subject.affectedItemsChecked.push_back(itemInCell)
			else:
				canAffect = item.affectsEmpty(color)

			if item.isBag():
				if canAffect:
					tileToCells[subject.AffectedTile.AffectsInside].push_back(cell)
			else:
				if canAffect:
					tileToCells[subject.AffectedTile.CanAffect + color].push_back(cell)
				else:
					tileToCells[subject.AffectedTile.CannotAffect + color].push_back(cell)
		elif subject.isInventoryCell(cell):
			tileToCells[subject.AffectedTile.CannotAffect + color].push_back(cell)

	return tileToCells

static func tryAddItem(subject: Receiver, item: Item, hotswapAllowed: bool) -> int:
	if item.pve_is_view(): return Expedition.bridge.drop_item(item)
	var insideCells = subject.getPlacableCells()

	var firstPoint: Vector2
	var firstCell: Vector2
	var cells
	var hotswap = false

	if item.isBag():
		var extensionPoints = item.getExtensionPoints()
		cells = subject.getCellsForGlobalPositions(extensionPoints)

		for cell in cells:
			if not subject.isInventoryCell(cell):
				return Item.DropResult.OutsideInventory

		var bagCollisions = subject.getBagsInCells(cells)

		if bagCollisions.is_empty():

			pass
		else:
			if (Game.state != Game.State.Shop or
				CustomRules.getCannotPickBags()):
				return Item.DropResult.InventoryCollision

			if bagCollisions.size() == 1:
				hotswap = true
				bagCollisions[0].pickup(Item.PickupType.Hotswap)
			else:
				Game.STORAGEBOX.pushItemsToStorage(bagCollisions)

		firstPoint = extensionPoints[0]
		firstCell = cells[0]

	else:
		var collisionPoints = item.getCollisionPoints()

		cells = subject.getCellsForGlobalPositions(collisionPoints)
		var difToCenter = collisionPoints[0] - subject.tilemap.to_global(LegacyGrid.cell_origin(subject.tilemap, cells[0]) + subject.halfCellSize)

		var shiftDirections
		if item.canSnap():
			shiftDirections = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
				Vector2( - 1, - 1), Vector2( - 1, 1), Vector2(1, - 1), Vector2(1, 1)]

			var sorter = subject.DistanceSorter.new(difToCenter.normalized())
			shiftDirections.sort_custom(Callable(sorter, "sort"))
			shiftDirections.push_front(Vector2.ZERO)
		else:
			shiftDirections = [Vector2.ZERO]

		var itemCollisions = Dictionary()
		var foundShift = null

		for dir in shiftDirections:
			itemCollisions.clear()
			var noCellsOutside = true
			for cell in cells:
				var shiftedCell = cell + dir
				if not shiftedCell in insideCells:
					noCellsOutside = false
					break

				var itemInCell = subject.filledCells.get(shiftedCell, null)
				if itemInCell:
					itemCollisions[itemInCell] = true

			if noCellsOutside:
				foundShift = dir
				break

		if foundShift == null:
			return Item.DropResult.OutsideInventory
		else:

			for i in collisionPoints.size():
				collisionPoints[i] += foundShift * subject.cellSize
			for i in cells.size():
				cells[i] += foundShift
			item.global_translate(foundShift * subject.cellSize)

		if itemCollisions.is_empty():

			pass
		elif itemCollisions.size() == 1:
			var collider = itemCollisions.keys()[0]
			if hotswapAllowed:
				hotswap = true
				var hotswapItem = collider
				hotswapItem.pickup(Item.PickupType.Hotswap)
			else:
				return Item.DropResult.InventoryCollision
		else:
			if Game.state == Game.State.Shop:

				for collider in itemCollisions:
					subject.removeItem(collider)

				subject.addItemCells(item, cells)

				var oldPositions = Dictionary()
				for collider in itemCollisions:
					oldPositions[collider] = collider.global_position

				var freePositions = []
				for collider in itemCollisions:
					var topLeftCell = collider.getTopLeftCell()
					var faceDirection = collider.getFaceDirection()
					var options = []
					for offset in subject.neighborOffsets:
						var offsetTopLeft = topLeftCell + offset
						subject.orientItem(collider, offsetTopLeft, faceDirection)
						if subject.canAddItem(collider):
							options.push_back(offsetTopLeft)

					freePositions.push_back([collider, options])

				freePositions.sort_custom(Callable(subject.CollisionSorter, "lessOptions"))

				var hotswapItem = null
				var pushToStorage = []

				for i in freePositions.size():
					var collider = freePositions[i][0]
					var options = freePositions[i][1]
					var faceDirection = collider.getFaceDirection()
					var added = false

					for topLeftCell in options:
						subject.orientItem(collider, topLeftCell, faceDirection)
						if subject.canAddItem(collider):
							added = true

							subject.addItemByTopLeft(collider, topLeftCell)
							collider.moveTo(oldPositions[collider], collider.global_position)
							break

					if hotswapAllowed:
						if not added:

							if hotswapItem == null:
								hotswapItem = collider
								hotswapItem.pickup(Item.PickupType.Hotswap)
								hotswap = true
							else:
								pushToStorage.push_back(collider)
						elif i == freePositions.size() - 1 and hotswapItem == null:
							hotswapItem = collider
							hotswapItem.pickup(Item.PickupType.Hotswap)
							hotswap = true
					else:
						if not added:
							pushToStorage.push_back(collider)

				Game.STORAGEBOX.pushItemsToStorage(pushToStorage)
			else:
				return Item.DropResult.InventoryCollision

		firstPoint = collisionPoints[0]
		firstCell = cells[0]

	var dif = firstPoint - subject.tilemap.to_global(LegacyGrid.cell_origin(subject.tilemap, firstCell) + subject.halfCellSize)
	item.global_translate( - dif)

	subject.addItem(item, cells, true)

	if Game.inventoryEditMode == Game.InventoryEditMode.Default:
		subject.pushFloatingItemsToStorage()

	if hotswap:
		return Item.DropResult.Hotswap
	else:
		return Item.DropResult.AddedToInventory

static func addItemByTopLeft(subject: Receiver, item: Item, topLeftCell: Vector2):

	var curPos = item.getTopLeftGlobal()
	var targetPos = subject.tilemap.to_global(LegacyGrid.cell_origin(subject.tilemap, topLeftCell))

	item.global_translate(targetPos - curPos)
	if item.isBag():
		subject.addItem(item, subject.getCellsForGlobalPositions(item.getExtensionPoints()), false)
	else:
		subject.addItem(item, subject.getCellsForGlobalPositions(item.getCollisionPoints()), false)

static func addItem(subject: Receiver, item: Item, cells, placedByPlayer: bool):
	if item.pve_is_view():
		if item in subject.items: subject.clearItemCells(item)
		subject.addItemCells(item, cells)
		if item not in subject.items: subject.items.append(item)
		item.addToInventory(subject, cells, placedByPlayer)
		subject.recalculateTilemap()
		return

	subject.addItemCells(item, cells)
	subject.recalculateTilemap()
	subject.items.push_back(item)
	item.addToInventory(subject, cells, placedByPlayer)
	Game.onInventoryChanged()
	subject.emit_signal("item_added", item)

static func replaceItem(subject: Receiver, item, newItem):
	var topLeftCell = item.getTopLeftCell()
	var faceDirection = item.getFaceDirection()
	topLeftCell += newItem.getCraftingOffset(faceDirection)

	subject.removeItem(item)
	item.discard(false)

	newItem.ownerType = Item.Owner.PlayerInventory
	subject.itemNode.add_child(newItem)

	var added = false
	for offset in subject.aroundOffsets:
		var offsetTopLeft = topLeftCell + offset
		subject.orientItem(newItem, offsetTopLeft, faceDirection)

		if subject.canAddItem(newItem):
			subject.addItemByTopLeft(newItem, offsetTopLeft)
			added = true
			break

	if not added:
		newItem.pushToStorage(Game.STORAGEBOX.center)

	return added

static func getRightBorder(subject: Receiver):
	var rightMostCell = - 1

	for cell in subject.bagCells:
		if cell.x > rightMostCell:
			rightMostCell = cell.x

	if Game.inventoryEditMode != Game.InventoryEditMode.Default:
		for cell in subject.filledCells:
			if cell.x > rightMostCell:
				rightMostCell = cell.x

	return subject.tilemap.global_position.x + LegacyGrid.cell_origin(subject.tilemap, Vector2(rightMostCell, 0)).x

static func canShift(subject: Receiver, direction: Vector2):

	if CustomRules.getCannotPickBags() and Game.inventoryEditMode != Game.InventoryEditMode.ItemLayer:
		return false

	for cell in subject.getBorderCells(direction):
		if Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer:
			if subject.isItemInCell(cell):
				subject.playShiftCollisionAni(direction)
				return false
		else:
			if not subject.isPotentialSpace(cell):
				subject.playShiftCollisionAni(direction)
				return false

	return true

static func playShiftCollisionAni(subject: Receiver, direction):
	var ani = ObjectPool.instantiate(subject.shiftCollisionAni)
	Game.UINode.add_child(ani)
	ani.get_node("AnimationPlayer").play("Appear", - 1, 2)
	if direction == Vector2.UP:
		ani.position = Vector2(410, 50)
		ani.scale = subject.shiftCollisionScale_large
		ani.rotation = 0
	elif direction == Vector2.DOWN:
		ani.position = Vector2(410, 636)
		ani.scale = subject.shiftCollisionScale_large
		ani.rotation = 0
	if direction == Vector2.LEFT:
		ani.position = Vector2(40, 343)
		ani.scale = subject.shiftCollisionScale_small
		ani.rotation = PI * 0.5
	if direction == Vector2.RIGHT:
		ani.position = Vector2(777, 343)
		ani.scale = subject.shiftCollisionScale_small
		ani.rotation = PI * 0.5

static func _unhandled_input(subject: Receiver, event):
	if InputBlocker.isActive(): return

	if Game.state == Game.State.Shop:
		var shiftDir = Vector2.ZERO
		if Util.isActionPressed_event(event, "shift_up"):
			shiftDir = Vector2.UP
		if Util.isActionPressed_event(event, "shift_left"):
			shiftDir = Vector2.LEFT
		if Util.isActionPressed_event(event, "shift_right"):
			shiftDir = Vector2.RIGHT
		if Util.isActionPressed_event(event, "shift_down"):
			shiftDir = Vector2.DOWN

		if shiftDir != Vector2.ZERO:
			if subject.canShift(shiftDir):
				subject.shift(shiftDir)

static func getMultiSelectItems(subject: Receiver):
	if subject.multiSelectMainItem.isBag():
		var totalSelection = subject.multiSelectSubItems.duplicate()

		if Game.inventoryEditMode == Game.InventoryEditMode.Default:
			totalSelection.append_array(subject.multiSelectMainItem.getItemsInside())
			for bag in subject.multiSelectSubItems:
				totalSelection.append_array(bag.getItemsInside())

		totalSelection = Util.filterDuplicates(totalSelection)
		return totalSelection
	else:
		return subject.multiSelectSubItems.duplicate()

static func createFromItemTuples(subject: Receiver, itemTuples: Array, ownerType: int):
	subject.reset()
	itemTuples.sort_custom(Callable(Game.ItemSort, "sort_BagOrder"))

	for tuple in itemTuples:
		var descriptor = tuple["d"]
		var item
		if ownerType == Item.Owner.BuildViewer:
			item = descriptor.instantiate_pooled()
		else:
			item = ItemBook.instantiateItem(descriptor)
		item.ownerType = ownerType
		subject.itemNode.add_child(item)
		var topLeftCellPos = tuple["c"]
		var faceDirection = tuple["f"]
		item.setFaceDirectionInstant(faceDirection)
		subject.orientItem(item, topLeftCellPos, faceDirection)
		if not subject.canAddItemOrBag(item):
			Util.eprint("overlapping item: ", item.getName())
		subject.addItemByTopLeft(item, topLeftCellPos)

		if "g" in tuple:
			var gems = tuple["g"]
			for i in gems.size():
				var gemIndex = gems[i]
				if gemIndex != RunDatabase.emptySocketId:
					var gem
					if ownerType == Item.Owner.BuildViewer:
						gem = ItemBook.getGemForIndex(gemIndex).instantiate_pooled()
					else:
						gem = ItemBook.instantiateItem(ItemBook.getGemForIndex(gemIndex))
					item.setGem(i, gem)

		if "pd" in tuple:
			item.setData(tuple["pd"])

static func pve_nav_ready(subject: Receiver) -> bool:
	return Expedition.bridge != null and Expedition.active and subject == Game.PLAYER.INVENTORY and Game.state == Game.State.Shop and Expedition.flow.screen_state == "SHOP_PREPARE" and not InputBlocker.isActive() and (Expedition.panel == null or not Expedition.panel.visible)

static func pve_selected_item(subject: Receiver):
	if subject.pve_zone == "shop": return Game.shopSceneNode.slots[clampi(subject.pve_slot, 0, 4)].item
	if subject.pve_zone == "storage": return Game.STORAGEBOX.items[subject.pve_slot] if subject.pve_slot < Game.STORAGEBOX.items.size() else null
	var item = subject.filledCells.get(Vector2(subject.pve_cursor))
	return item if is_instance_valid(item) else subject.bagCells.get(Vector2(subject.pve_cursor))

static func pve_place_held(subject: Receiver):
	var item = Game.draggedItem
	if item == null or not subject.pve_navigation_active: return
	item.set_meta("pve_grid_navigation", true)
	if subject.pve_zone == "inventory": subject.orientItem(item, Vector2(subject.pve_cursor), item.getFaceDirection())
	elif subject.pve_zone == "storage": item.global_position = Game.STORAGEBOX.pve_slot_rect(subject.pve_slot).get_center()

static func pve_navigate(subject: Receiver, direction: Vector2i):
	subject.pve_navigation_active = true
	if subject.pve_zone == "inventory":
		subject.pve_cursor.x = clampi(subject.pve_cursor.x + direction.x, 0, 8)
		subject.pve_cursor.y = clampi(subject.pve_cursor.y + direction.y, 0, 6)
	else:
		var count = 5 if subject.pve_zone == "shop" else int(Expedition.flow.run.build.storage_capacity)
		subject.pve_slot = posmod(subject.pve_slot + direction.x + direction.y, count)
	subject.pve_place_held()

static func pve_activate_selection(subject: Receiver):
	if Game.draggedItem != null:
		if subject.pve_zone == "shop": return
		subject.pve_place_held()
		var item = Game.draggedItem
		var result = item.drop()
		item.reactToDropResult(result)
		return
	var item = subject.pve_selected_item()
	if not is_instance_valid(item): return
	if item.ownerType == Item.Owner.Shop and not item.affordable:
		Expedition.notice("not_enough_gold"); return
	item.pickup()
	item.set_meta("pve_grid_navigation", true)
	if subject.pve_zone == "shop" or subject.pve_zone == "storage": subject.pve_zone = "inventory"
	var found = Expedition.flow.placement.find(Expedition.flow.run.build, str(item.get_meta("pve_uid", "")))
	if not found.is_empty() and found.layer != "storage": subject.pve_cursor = Vector2i(int(found.entry.x), int(found.entry.y))
	subject.pve_place_held()

static func _input(subject: Receiver, event: InputEvent):
	if not Expedition.enabled or not subject.pve_nav_ready(): return
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 1:
			subject.pve_navigation_active = false
			if Game.draggedItem != null: Game.draggedItem.set_meta("pve_grid_navigation", false)
			if is_instance_valid(subject.pve_focused_item):
				Game.unhoverAllItems(false)
				subject.pve_focused_item = null
				for under_mouse in Game.itemsUnderMouse.duplicate():
					if is_instance_valid(under_mouse): under_mouse.hover()
		return
	if event is InputEventMouseButton: return
	for region_action in ["pve_next_region", "pve_prev_region"]:
		if InputMap.has_action(region_action) and event.is_action(region_action):
			var pressed = event.is_action_pressed(region_action)
			if pressed and not bool(subject.pve_region_pressed.get(region_action, false)):
				subject.pve_cycle_zone(1 if region_action == "pve_next_region" else -1)
			subject.pve_region_pressed[region_action] = pressed
			subject.get_viewport().set_input_as_handled()
			return
	var direction = Vector2i.ZERO
	var directions = {"ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT, "ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN, "move_cursor_left": Vector2i.LEFT, "move_cursor_right": Vector2i.RIGHT, "move_cursor_up": Vector2i.UP, "move_cursor_down": Vector2i.DOWN}
	var axis_navigation = false
	for action in directions:
		if not InputMap.has_action(action) or not event.is_action(action): continue
		if event is InputEventJoypadMotion: axis_navigation = true
		if event.is_action_pressed(action): direction = directions[action]
	if axis_navigation:
		if direction == subject.pve_repeat_direction: subject.get_viewport().set_input_as_handled(); return
		subject.pve_repeat_direction = direction
		subject.pve_repeat_wait = 0.32
	if direction != Vector2i.ZERO:
		subject.pve_navigate(direction)
	elif event.is_action_pressed("ui_accept"):
		subject.pve_navigation_active = true
		subject.pve_activate_selection()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("options"):
		if Game.draggedItem == null: return
		Expedition.bridge.cancel_drag(Game.draggedItem)
	elif event.is_action_pressed("ui_focus_prev", false, true):
		subject.pve_cycle_zone(-1)
	elif event.is_action_pressed("ui_focus_next"):
		subject.pve_cycle_zone()
	elif Game.draggedItem != null and subject.pve_navigation_active and Util.isActionPressed_event(event, "rotate_right_button"):
		Game.draggedItem.rotateRight(); subject.pve_place_held()
	elif Game.draggedItem != null and subject.pve_navigation_active and Util.isActionPressed_event(event, "rotate_left_button"):
		Game.draggedItem.rotateLeft(); subject.pve_place_held()
	elif Util.isActionPressed_event(event, "push_to_storage"):
		var item = Game.draggedItem if Game.draggedItem != null else subject.pve_selected_item()
		if not is_instance_valid(item): return
		var result = Expedition.bridge.store_item(item)
		if result.ok or bool(result.get("committed_in_memory", false)) or item.dragged:
			item.reactToDropResult(Item.DropResult.AddedToStorageBox if result.ok or bool(result.get("committed_in_memory", false)) else Item.DropResult.OutsideInventory)
	elif Util.isActionPressed_event(event, "reserve") and subject.pve_zone == "shop":
		var offer = Game.shopSceneNode.slots[subject.pve_slot]
		Expedition.bridge.set_lock(offer, not bool(Expedition.bridge.slot_data(subject.pve_slot).get("locked", false)))
	else: return
	subject.get_viewport().set_input_as_handled()

static func pve_update_navigation(subject: Receiver, delta: float):
	if subject.pve_cursor_sprite != null: subject.pve_cursor_sprite.visible = subject.pve_navigation_active and subject.pve_nav_ready()
	if not subject.pve_nav_ready():
		subject.pve_repeat_direction = Vector2i.ZERO
		return
	if not subject.pve_navigation_active: return
	var selected = Game.draggedItem if Game.draggedItem != null else subject.pve_selected_item()
	if not is_instance_valid(selected): selected = null
	if subject.pve_focused_item != selected or Game.getFocusItem() != selected:
		Game.unhoverAllItems(false)
		subject.pve_focused_item = selected
		if selected != null: selected.hover()
	if subject.pve_repeat_direction != Vector2i.ZERO:
		subject.pve_repeat_wait -= delta
		if subject.pve_repeat_wait <= 0:
			subject.pve_repeat_wait = 0.11
			subject.pve_navigate(subject.pve_repeat_direction)
	if subject.pve_cursor_sprite == null:
		subject.pve_cursor_sprite = Sprite2D.new()
		subject.pve_cursor_sprite.texture = load("res://Items/Tiles/Hover.png")
		subject.pve_cursor_sprite.modulate = Color(0.45, 0.9, 1.0, 0.85)
		subject.pve_cursor_sprite.z_index = 100
		subject.add_child(subject.pve_cursor_sprite)
	if subject.pve_zone == "inventory": subject.pve_cursor_sprite.global_position = subject.cellToGlobalPos(Vector2(subject.pve_cursor), true)
	elif subject.pve_zone == "shop": subject.pve_cursor_sprite.global_position = Game.shopSceneNode.slots[subject.pve_slot].global_position + Vector2(-80, -60)
	else: subject.pve_cursor_sprite.global_position = Game.STORAGEBOX.pve_slot_rect(subject.pve_slot).get_center()

static func getCellsInLine(cells, direction: Vector2, distance):
	var lineCells = []
	for cell in cells:
		for offset in range(1, distance + 1):
			var neighbor = cell + direction * offset

			if ( not neighbor in cells and
				not neighbor in lineCells):
				lineCells.push_back(neighbor)

	return lineCells

static func getAdjacentCells(cells):
	var adjacentCells = []
	for cell in cells:
		for offset in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var neighbor = cell + offset

			if ( not neighbor in cells and
				not neighbor in adjacentCells):
				adjacentCells.push_back(neighbor)

	return adjacentCells
