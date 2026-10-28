extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/SelectionBox.gd")

static func _ready(subject: Receiver):
	Game.selectionBox = subject
	subject.set_process(false)
	subject.boxVisual.hide()
	subject.collisionShape.disabled = true

	subject.spaceStateQuery = PhysicsShapeQueryParameters2D.new()
	subject.grabbingShape.radius = 80
	subject.spaceStateQuery.set_shape(subject.grabbingShape)
	subject.spaceStateQuery.collide_with_bodies = true
	subject.spaceStateQuery.collision_mask = 8
	var excluded_rids: Array[RID] = []
	for wall in subject.get_tree().get_nodes_in_group("Wall"):
		if wall is CollisionObject2D:
			excluded_rids.append(wall.get_rid())
	subject.spaceStateQuery.exclude = excluded_rids
	subject.spaceStateQuery.collide_with_areas = false

	Game.connect("combat_start_pressed", Callable(subject, "cancel"))
	Game.connect("game_paused", Callable(subject, "cancel"))

static func canStart(subject: Receiver) -> bool:
	return (Game.state == Game.State.Shop and
			not Game.isMenuOpen() and
			Game.draggedItem == null and
			not Game.replacementPending and
			Util.time > Game.lastItemDropTime and
			(Game.getFocusItem() == null or not Game.getFocusItem().canBeLocked()) and
			Input.get_current_cursor_shape() == Input.CURSOR_ARROW)

static func _input(subject: Receiver, event):
	if InputBlocker.isActive(): return

	if (Util.isAction_event(event, "grab_item") or
		event is InputEventScreenTouch):

		subject.closestItem = null
		if event.is_pressed():

			if Game.isTouchScreenActive():

				Game.unhoverAllItems()

				var items = subject.findTouchedItems(subject.get_global_mouse_position())
				for item in items:
					item.hover()

static func _unhandled_input(subject: Receiver, event):
	if InputBlocker.isActive(): return

	var leftClick = (Util.isAction_event(event, "grab_item") or
		event is InputEventScreenTouch)
	var rightClick = Util.isAction_event(event, "lock_combining")

	if leftClick or rightClick:
		var curMousePos = subject.get_global_mouse_position()

		if event.is_pressed():
			if Game.SELECTING: return

			if subject.canStart():
				if Game.inventoryEditMode == Game.InventoryEditMode.BagLayer:
					subject.withoutBags = false
				elif Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer:
					subject.withoutBags = true
				else:
					subject.withoutBags = rightClick

				if subject.withoutBags:
					subject.boxVisual.modulate = Color(0.52, 1.2, 0.5)
				else:
					subject.boxVisual.modulate = Color.WHITE

				if CustomRules.getCannotPickBags():
					subject.withoutBags = true

				subject.startedWithLeftClick = leftClick

				subject.startPoint = curMousePos

				if (curMousePos.x > 750 and
					subject.startedWithLeftClick and
					subject.findAndPickCloseItem()):
						return

				subject.startSelecting()
				Game.cancelSwitch()

		else:
			if not Game.SELECTING: return
			if subject.startedWithLeftClick != leftClick: return

			if not subject.selectedInventoryItems.is_empty():
				var curFrame = Util.getFrameCounter_process()
				if curFrame - subject.startFrame > 2:
					var mainBag = null
					var closestDist = 10000
					for bag in subject.selectedInventoryItems:
						var dist = bag.global_position.distance_to(curMousePos)
						if dist < closestDist:
							closestDist = dist
							mainBag = bag
					subject.selectedInventoryItems.erase(mainBag)

					Game.PLAYER.INVENTORY.startMultiSelect(mainBag, subject.selectedInventoryItems)
					Game.setTutorialDone(Game.TutorialSteps.Selection)
				subject.end()

			else:

				if (Util.time > Game.lastItemDropTime + 0.5 and
					(subject.startedWithLeftClick or
						subject.collisionShape.shape.size.x > 60 or
						subject.collisionShape.shape.size.y > 60)
					):

					if subject.findAndPickCloseItem():
						return

					if not subject.selectedStorageItems.is_empty():
						var closest = null
						var closestDist = 1000000
						for item in subject.selectedStorageItems:
							var dist = item.global_position.distance_to(curMousePos)
							if dist < closestDist:
								closestDist = dist
								closest = item

						subject.end()

						Game.disableTooltipsFor(6)
						closest.pickup()
						return

				subject.end()
				var focusItem = Game.getFocusItem()
				if focusItem != null:
					focusItem.gainFocus()

static func findTouchedItems(subject: Receiver, atPos) -> Array:
	var spaceState = subject.get_world_2d().get_direct_space_state()
	var query = PhysicsPointQueryParameters2D.new()
	query.position = atPos
	query.collision_mask = 1
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var results = spaceState.intersect_point(query, 32)
	var items = []
	for result in results:
		var object = result.collider.get_parent()
		if object is Item:
			items.push_back(object)
	return items

static func findTouchedItem(subject: Receiver, atPos):
	var spaceState = subject.get_world_2d().get_direct_space_state()
	var query = PhysicsPointQueryParameters2D.new()
	query.position = atPos
	query.collision_mask = 1
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var results = spaceState.intersect_point(query, 32)

	var bestMatch = null
	var bestScore = - 1
	for result in results:
		var object = result.collider.get_parent()
		if object is Item:
			var score = subject.getScore(object)
			if score > bestScore:
				bestScore = score
				bestMatch = object
	return bestMatch

static func onItemAreaEntered(subject: Receiver, itemArea):
	if not Game.SELECTING: return
	var item = itemArea.get_parent()
	if subject.canPickFromInventory(item):
		subject.selectedInventoryItems.push_back(item)
		item.setBright()
		var numItems = subject.selectedInventoryItems.size()

		var pitchLoopSize = 24
		var rising = pitchLoopSize / 2
		var pitchLevel = numItems % pitchLoopSize
		if pitchLevel > rising:
			pitchLevel = pitchLoopSize - pitchLevel
		var pitch = 0.6 + pitchLevel * 0.1

		Sound.playSound_process(item.hoverSound, 0, pitch)

	elif subject.canPickFromStorage(item):
		subject.selectedStorageItems.push_back(item)

static func _process(subject: Receiver, delta):
	var curPoint = subject.get_global_mouse_position()
	var topLeft = Vector2(min(subject.startPoint.x, curPoint.x), min(subject.startPoint.y, curPoint.y))
	var bottomRight = Vector2(max(subject.startPoint.x, curPoint.x), max(subject.startPoint.y, curPoint.y))

	subject.boxVisual.global_position = topLeft
	subject.boxVisual.set_end(bottomRight)

	var clampedTopLeft = Vector2(min(topLeft.x, subject.BOTTOM_RIGHT_BORDER.x),
									min(topLeft.y, subject.BOTTOM_RIGHT_BORDER.y))
	var clampedBottomRight = Vector2(min(bottomRight.x, subject.BOTTOM_RIGHT_BORDER.x),
										min(bottomRight.y, subject.BOTTOM_RIGHT_BORDER.y))

	subject.area.position = (clampedBottomRight + topLeft) * 0.5
	subject.collisionShape.shape.size = clampedBottomRight - topLeft
