extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func setEditMode(subject: Receiver, active: bool):
	if active:
		if subject.ownerType != subject.Owner.Shop or subject.affordable:
			subject.enablePicking()
		subject.enableFocus()
		subject.clickArea.show()
		subject.modulate.a = 1.0
		subject.setShadowAlpha(1.0)
	else:
		if subject.hovered_state: subject.hoverEnd()
		subject.disableFocus()
		subject.clickArea.hide()
		subject.disablePicking()
		subject.modulate.a = 0.6
		subject.setShadowAlpha(0.3)

static func getNormalizedCollisionCells(subject: Receiver) -> Array:
	var cells
	if subject.isBag():
		cells = subject.getExtensionCells().duplicate()
	else:
		cells = subject.getCollisionCells().duplicate()

	var minimum = Vector2(100, 100)
	for cell in cells:

		if cell.y <= minimum.y:
			if cell.y < minimum.y:
				minimum.x = cell.x
			else:

				minimum.x = min(cell.x, minimum.x)
			minimum.y = cell.y

	for i in cells.size():
		cells[i] = cells[i] - minimum

	var cellOffset = LegacyGrid.cell_origin(subject.collisionMap, minimum) + subject.collisionMap.position + Vector2(40, 40)

	return [cells, cellOffset]

static func getTopLeftGlobal(subject: Receiver) -> Vector2:
	if subject.pve_is_view() and subject.has_meta("pve_anchor"):
		var origin: Vector2 = subject.get_meta("pve_anchor")
		var size: Vector2 = subject.get_meta("pve_size")
		var minimum = Vector2(INF, INF)
		for corner in [origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y)]:
			var point = subject.to_global(corner)
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
		return minimum
	var topLeft = Vector2(INF, INF)
	for cell in subject.collisionCells:
		var globalPos = subject.collisionMap.to_global(LegacyGrid.cell_origin(subject.collisionMap, cell))
		topLeft.x = min(globalPos.x, topLeft.x)
		topLeft.y = min(globalPos.y, topLeft.y)
	return topLeft + subject.correction[subject.getFaceDirection()]

static func getBottomRightGlobal(subject: Receiver) -> Vector2:
	if subject.pve_is_view() and subject.has_meta("pve_anchor"):
		var origin: Vector2 = subject.get_meta("pve_anchor")
		var size: Vector2 = subject.get_meta("pve_size")
		var maximum = Vector2(-INF, -INF)
		for corner in [origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y)]:
			var point = subject.to_global(corner)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
		return maximum
	var bottomRight = Vector2( - INF, - INF)
	for cell in subject.collisionCells:
		var globalPos = subject.collisionMap.to_global(LegacyGrid.cell_origin(subject.collisionMap, cell))
		bottomRight.x = max(globalPos.x, bottomRight.x)
		bottomRight.y = max(globalPos.y, bottomRight.y)
	return bottomRight + subject.cellSize

static func previewCells(subject: Receiver):
	if subject.pve_is_view():
		subject.collisionMap.hide()
		return
	if not subject.isBag():
		subject.collisionMap.show()

	var globalCollisionPoints = subject.getCollisionPoints()
	var rotatedCells = subject.getCellsForGlobalPositions(globalCollisionPoints)
	for color in [subject.Affected.Primary, subject.Affected.Secondary]:
		var nonMappedCells = subject.getAffectedCellsAfterRotate(rotatedCells, color)

		if not nonMappedCells.is_empty():
			for cell in LegacyGrid.used_cells_by_id(subject.collisionMap, subject.Tiles.AffectedDynamic + color):
				subject.collisionMap.set_cell(0, Vector2i(cell), - 1, Vector2i.ZERO, 0)

			for cell in nonMappedCells:
				subject.collisionMap.set_cell(0, Vector2i(cell), subject.Tiles.AffectedDynamic + color, Vector2i.ZERO, 0)
