extends Node2D

signal item_added
signal item_removed
signal item_type_changed
signal inventory_shifted

enum Tile{
	Outside = - 1,
	PotentialSpaceHovered = 7,
	PotentialSpace = 8,
	Empty = 2,
	Filled = 1,
	HoveredOK = 6,
	HoveredFail = 5,
	Collision = 4,
	HoveredOutside = 9,
	HoveredOK_Bag = 10,
	HoveredFail_Bag = 11,
}

enum AffectedTile{
	CanAffect = 0,
	CannotAffect = 1,
	CanAffectSecondary = 2,
	CannotAffectSecondary = 3,
	CanAffectTertiary = 4,
	CannotAffectTertiary = 5,
	AffectsInside = 6,
	CanAffectLightning = 7,
	CannotAffectLightning = 8,
}

const shiftSound = preload("res://Assets/Sound/Switch.wav")
var shiftCollisionAni = load("res://Interface/InventoryBorder.tscn")

const MAX_SIZE = Vector2(10, 10)
@export var inventorySize = Vector2(9, 7)
const cellSize = Vector2(80, 80)
const halfCellSize = Vector2(40, 40)
const neighborOffsets = [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
const aroundOffsets = [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2( - 1, - 1), Vector2(1, - 1), Vector2( - 1, 1), Vector2(1, 1)]
const hoveredTiles = [Tile.HoveredOK, Tile.HoveredFail, Tile.Collision]

@onready var tilemap = $TileMap
@onready var aboveTilemap = $Above
@onready var itemNode = get_parent()
@onready var inventoryCells = LegacyGrid.used_cells(tilemap)

var filledCells: Dictionary
var bagCells: Dictionary
var borderCells: Dictionary
var items = []
var character = null
var curHovered: Dictionary
var recalculateQueued = false

func _ready() -> void :
	load("res://Runtime/Behavior/Core/InventoryBehavior.gd")._ready(self)

func isInventoryCell(cell):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").isInventoryCell(self, cell)

func isTilePotentialSpace(tile):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").isTilePotentialSpace(self, tile)

func isPotentialSpace(cell):
	return isInventoryCell(cell) and not cell in bagCells

func isItemInCell(cell):
	return cell in filledCells

func getInsideCells():
	var insideCells = []
	for cell in inventoryCells:
		if cell in bagCells:
			insideCells.push_back(cell)

	return insideCells

func getPlacableCells():
	if Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer:
		return inventoryCells
	else:
		return getInsideCells()

func _process(delta: float) -> void :
	if Expedition.enabled: pve_update_navigation(delta)
	if Game.draggedItem:
		cleanUp()
	aboveTilemap.clear()

func recalculateTilemap():
	if not recalculateQueued:
		recalculateQueued = true
		call_deferred("actuallyRecalculateTilemap")

func actuallyRecalculateTilemap():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").actuallyRecalculateTilemap(self)

func cleanUp():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").cleanUp(self)

func canAddItemOrBag(item: Item):
	if item.isBag():
		return canAddBag(item)
	else:
		return canAddItem(item)

func canAddBag(bag, checkCollisions = true):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").canAddBag(self, bag, checkCollisions)

func canAddItem(item: Item, checkCollision = true, checkBags = true):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").canAddItem(self, item, checkCollision, checkBags)

func previewItem(item):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").previewItem(self, item)

func clearHoveredCache():
	curHovered.clear()

func isHovered(cell: Vector2) -> bool:

	return cell in curHovered

var affectedItemsChecked: Array

func previewAffectedCells(item):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").previewAffectedCells(self, item)

func getAffectedCells(item, color: int) -> Dictionary:
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").getAffectedCells(self, item, color)

func isDistinct(item):
	for affectedItem in affectedItemsChecked:
		if item.isA(affectedItem.descriptor):
			return false
	return true

func getAffectedPoints(item, color = Item.Affected.Primary):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").getAffectedPoints(self, item, color)

func getItems() -> Array:
	return items

func getItemsAndGems() -> Array:
	var itemsAndGems = items.duplicate()
	for item in items:
		itemsAndGems.append_array(item.getGemsNoNull())
	return itemsAndGems

func getCellsForGlobalPositions(points: Array) -> Array:
	var cells = []
	for point in points:
		cells.push_back(LegacyGrid.cell(tilemap, tilemap.to_local(point)))
	return cells

func cellToGlobalPos(cell: Vector2, cellCenter: bool = false) -> Vector2:
	var pos = tilemap.global_position + cellSize * cell
	if cellCenter:
		pos += halfCellSize
	return pos

func allCellsPotentialSpace(cells: Array):
	for cell in cells:
		if not isPotentialSpace(cell):
			return false
	return true

func isItemFloating(item) -> bool:
	for cell in item.occupiedCells:
		if not cell in bagCells:
			return true
	return false

func pushFloatingItemsToStorage():
	return

func tryAddItem(item: Item, hotswapAllowed: bool = true) -> int:
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").tryAddItem(self, item, hotswapAllowed)

func addItemByTopLeft(item: Item, topLeftCell: Vector2):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").addItemByTopLeft(self, item, topLeftCell)

func addItem(item: Item, cells, placedByPlayer: bool):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").addItem(self, item, cells, placedByPlayer)

func addItemCells(item: Item, cells: Array):
	if item.isBag():
		for cell in cells:
			bagCells[cell] = item
	else:
		for cell in cells:
			filledCells[cell] = item

func clearItemCells(item: Item):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").clearItemCells(self, item)

func moveItem(item, newCells: Array):
	clearItemCells(item)

	addItemCells(item, newCells)
	recalculateTilemap()
	item.occupiedCells = newCells

func removeItem(item: Item):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").removeItem(self, item)

func getFreeBagCells():
	return Util.subtractDictFromArray(bagCells.keys(), filledCells)

func addItemWherePossible(item) -> bool:
	var pos = findPlaceForItem(item)
	if pos != null:
		addItemByTopLeft(item, pos)
		return true
	else:
		return false

func findPlaceForItem(item):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").findPlaceForItem(self, item)

static func getHorizontalCells(cells):
	var left = getCellsInLine(cells, Vector2.LEFT)
	var right = getCellsInLine(cells, Vector2.RIGHT)
	return Util.filterDuplicates(left + right)

static func getVerticalCells(cells):
	var up = getCellsInLine(cells, Vector2.UP)
	var down = getCellsInLine(cells, Vector2.DOWN)
	return Util.filterDuplicates(up + down)

static func getCellsInLine(cells, direction: Vector2, distance = 7):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").getCellsInLine(cells, direction, distance)

static func getAdjacentCells(cells):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").getAdjacentCells(cells)

func getAdjacentItems(item):
	return getItemsInCells(getAdjacentCells(item.occupiedCells))

func isCellEmpty(cell: Vector2) -> bool:
	return cell in bagCells and not cell in filledCells

func getEmptyCellsInCells(cells):
	var num = 0
	for cell in cells:
		if isCellEmpty(cell):
			num += 1
	return num

func getItemInCell(cell: Vector2):
	return filledCells.get(cell, null)

func getItemsInCells(cells) -> Array:
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").getItemsInCells(self, cells)

func countItemsInCells(cells) -> Dictionary:
	var itemCounter = {}
	for cell in cells:
		if filledCells.has(cell):
			Util.dictAdd(itemCounter, filledCells[cell])
	return itemCounter

func getBagsInCells(cells):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").getBagsInCells(self, cells)

func deleteItems():
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").deleteItems(self)

func reset():
	deleteItems()

	for cell in inventoryCells:
		tilemap.set_cell(0, Vector2i(cell), Tile.PotentialSpace, Vector2i.ZERO, 0)

func replaceItem(item, newItem):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").replaceItem(self, item, newItem)

func orientItem(item, topLeftCell, faceDirection) -> void :
	load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").orientItem(self, item, topLeftCell, faceDirection)

func orientAndAddItem(item, topLeftCell, faceDirection, checkCollision = false):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").orientAndAddItem(self, item, topLeftCell, faceDirection, checkCollision)

func getRightBorder():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").getRightBorder(self)

func getLeftBorder():
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").getLeftBorder(self)

func getBorderCells(direction: Vector2) -> Array:
	return borderCells[direction]

func canShift(direction: Vector2):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").canShift(self, direction)

const shiftCollisionScale_large = Vector2(1.645, 1.36)
const shiftCollisionScale_small = Vector2(1.26, 1.36)

func playShiftCollisionAni(direction):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").playShiftCollisionAni(self, direction)

func shift(direction: Vector2):
	Expedition.bridge.shift_inventory(direction)
	return

func _unhandled_input(event):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd")._unhandled_input(self, event)

func onItemDropped(_item, _dropResult):
	clearHoveredCache()

func onItemTypeChanged(item):
	emit_signal("item_type_changed", item)

var multiSelectMainItem = null
var multiSelectSubItems: Array

func startMultiSelect(mainItem: Item, selected: Array):
	multiSelectMainItem = mainItem
	multiSelectSubItems = selected
	multiSelectMainItem.pickup(Item.PickupType.MultiSelect)

func getMultiSelectItems():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").getMultiSelectItems(self)

func createFromItemTuples(itemTuples: Array, ownerType: int):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").createFromItemTuples(self, itemTuples, ownerType)

func disableItemTooltips():
	for item in getItemsAndGems():
		item.disableTooltip()
		item.disableFocus()

func enableItemTooltips():
	for item in getItemsAndGems():
		item.enableTooltip()
		item.enableFocus()

func countGold() -> int:
	var g = 0
	for item in getItemsAndGems():
		g += item.descriptor.getPrice()
	return g

func countSocketedGems() -> int:
	var numGems = 0
	for item in items:
		numGems += item.getGemsNoNull().size()
	return numGems

func changeBuffPower_allItems(buffType, amount):
	for item in getItemsAndGems():

		item.giveBuffPower(buffType, amount)

func changeBuffAmplification_allItems(buffType, amount):
	for item in getItemsAndGems():

		item.changeAmplificiationChancePercent(buffType, amount)

class CellSorter:
	static func sort(cell1, cell2):
		if cell1.y == cell2.y:
			return cell1.x < cell2.x
		return cell1.y < cell2.y

class CollisionSorter:
	static func lessOptions(tuple1, tuple2):
		return tuple1[1].size() < tuple2[1].size()

class DistanceSorter:
	var baseOffset: Vector2
	const DIAG_PUNISH_FACTOR = 1.7

	func _init(_baseOffset):
		baseOffset = _baseOffset

	func sort(dir1: Vector2, dir2: Vector2):
		if dir1.x != 0 and dir1.y != 0: dir1 *= DIAG_PUNISH_FACTOR
		if dir2.x != 0 and dir2.y != 0: dir2 *= DIAG_PUNISH_FACTOR
		return dir1.distance_squared_to(baseOffset) < dir2.distance_squared_to(baseOffset)

# Deterministic grid navigation. Controller input never warps a free mouse cursor.
var pve_cursor = Vector2i(4, 3)
var pve_zone = "inventory"
var pve_slot: int = 0
var pve_navigation_active: bool = false
var pve_cursor_sprite: Sprite2D
var pve_repeat_direction = Vector2i.ZERO
var pve_repeat_wait: float = 0.0
var pve_region_pressed: Dictionary = {}
var pve_focused_item

func pve_set_zone(zone: String):
	if zone not in ["inventory", "shop", "storage"]: return
	pve_zone = zone
	pve_slot = 0
	pve_navigation_active = true
	pve_place_held()

func pve_cycle_zone(direction: int = 1):
	return load("res://Runtime/Behavior/Features/Core/InventoryBehavior.gd").pve_cycle_zone(self, direction)

func pve_nav_ready() -> bool:
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").pve_nav_ready(self)

func pve_selected_item():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").pve_selected_item(self)

func pve_place_held():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").pve_place_held(self)

func pve_navigate(direction: Vector2i):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").pve_navigate(self, direction)

func pve_activate_selection():
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").pve_activate_selection(self)

func _input(event: InputEvent):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd")._input(self, event)

func pve_update_navigation(delta: float):
	return load("res://Runtime/Behavior/Core/InventoryBehavior.gd").pve_update_navigation(self, delta)

func _notification(what: int):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and Expedition.enabled:
		pve_repeat_direction = Vector2i.ZERO
		if is_instance_valid(Game.PLAYER) and self == Game.PLAYER.INVENTORY and Game.draggedItem != null and Game.draggedItem.has_meta("pve_definition_id"):
			Expedition.bridge.cancel_drag(Game.draggedItem)
