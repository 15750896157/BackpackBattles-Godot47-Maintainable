extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func _process(subject: Receiver, delta: float) -> void :

	if Game.state != Game.State.Combat and subject.animation.current_animation == "":
		subject.sprite.modulate = Color.WHITE

	if subject.focus and Game.tooltipsEnabled():
		if subject.placed:
			subject.inventory.previewAffectedCells(subject)

		else:
			if subject.affectedCellsActive:
				Game.PLAYER.INVENTORY.previewAffectedCells(subject)

	if subject.dragged:
		var pos = subject.global_position
		if not bool(subject.get_meta("pve_grid_navigation", false)):
			subject.global_position = Util.getMousePosInWindow()
			subject.global_position.y -= Settings.getVal(Settings.Setting.pick_offset) * Settings.PICK_OFFSET

		var dif = subject.global_position - pos
		var speed = dif.length() / delta
		var direction = dif.normalized()
		subject.momentumStrength = lerp(subject.momentumStrength, speed / 60, 20 * delta)

		subject.momentumStrength = min(subject.momentumStrength, 150.0)
		subject.momentum = direction * subject.momentumStrength

		if subject.momentumStrength > Util.rng.randf_range(5, 15):
			subject.dragParticles.activate()
		else:
			subject.dragParticles.deactivate()

		Sound.itemMovePlayer.volume_db = linear_to_db(clamp((subject.momentumStrength - 20) / 100.0, 0, 1) * (0.5 + 0.1 * subject.getNumCells()))

		if subject.draggedInsideItems.is_empty():
			var mainDif
			if abs(dif.x) > abs(dif.y):
				mainDif = dif.length() * sign(dif.x)
			else:
				mainDif = - dif.length() * sign(dif.y)

			subject.rotationMomentum += mainDif * subject.moveRotationMouseFactor

			subject.rotationMomentum -= subject.bonusRotation * subject.backforce * delta

			subject.rotationMomentum *= max(0, 1 - (subject.fric * delta))

			subject.bonusRotation += subject.rotationMomentum * subject.moveRotationSpeed * delta
			subject.bonusRotation = clamp(subject.bonusRotation, - subject.maxAngle, subject.maxAngle)

			subject.sprite.rotation_degrees = subject.bonusRotation

		if subject.pve_is_view() and bool(subject.get_meta("pve_grid_navigation", false)):
			pass # Logical navigation consumes rotation once in Inventory._input.
		elif Util.isActionJustPressed("rotate_right_button"):
			subject.rotateRight()
		elif Util.isActionJustPressed("rotate_left_button"):
			subject.rotateLeft()

		if Util.time >= subject.mouseWheelRotationReadyTime and not bool(subject.get_meta("pve_grid_navigation", false)):
			if Util.isActionJustPressed("rotate_right", false):
				subject.rotateRight()
				subject.mouseWheelRotationReadyTime = Util.time + 0.1
			elif Util.isActionJustPressed("rotate_left", false):
				subject.rotateLeft()
				subject.mouseWheelRotationReadyTime = Util.time + 0.1

		subject.previewCellCollision()

	elif subject.placed and Game.state != Game.State.Combat and not Game.SELECTING:
		var focusItem = Game.getFocusItem()
		if (focusItem != null and
			focusItem != subject and
			(focusItem.placed or focusItem == Game.draggedItem) and
			not focusItem.isBag()):
			var affectedPrimary = subject.canAffectDraggedItem(focusItem, subject.Affected.Primary)
			var affectedSecondary = subject.canAffectDraggedItem(focusItem, subject.Affected.Secondary)
			var affectedTertiary = subject.canAffectDraggedItem(focusItem, subject.Affected.Tertiary)
			var affectedLightning = subject.canAffectDraggedItem(focusItem, subject.Affected.Lightning)

			var sum = int(affectedPrimary) + int(affectedSecondary) + int(affectedTertiary)
			if sum > 1:
				subject.sprite.modulate = Color(1.3, 1.3, 1.3, 1)
			elif affectedPrimary:

				subject.sprite.modulate = Color(1.3, 1.3, 0.8, 1)
			elif affectedSecondary:
				subject.sprite.modulate = Color(1.0, 1.3, 0.9, 1)
			elif affectedTertiary:
				subject.sprite.modulate = Color(1.3, 0.9, 1.3, 1)
			elif affectedLightning:
				subject.sprite.modulate = Color(1.35, 1.25, 1.0, 1)

	subject.updateShadow()
	if subject.lock.visible:
		subject.lock.global_rotation = 0

	if subject.mode == 0 and subject.visible:
		subject.averagedPosition = lerp(subject.averagedPosition, subject.global_position, 1.5 * delta)
		var posDif = (subject.averagedPosition - subject.global_position).length()

		var curVelocity = subject.get_linear_velocity()
		var acceleration = (subject.lastVelocity - curVelocity).length()

		if posDif > 30 and acceleration > 50:

			if Util.time >= subject.impactSoundReadyTime:
				subject.playDropSound(Util.rng.randf_range( - 15, - 10))
				subject.impactSoundReadyTime = Util.time + 0.5

			var particles = ObjectPool.particleOneShot(subject.dustParticles, subject.get_parent().get_parent())
			if acceleration > 200:
				particles.amount = 12
			else:
				particles.amount = 6

			particles.z_index = subject.get_parent().z_index - 1

			var dir = subject.lastVelocity.normalized()
			particles.process_material.direction = Vector3(dir.x, dir.y, 0)
			particles.process_material.initial_velocity_min = subject.lastVelocity.length() * 0.4 + 120.0
			particles.process_material.initial_velocity_max = particles.process_material.initial_velocity_min
			particles.global_position = subject.lastCollisionPos

			if (is_instance_valid(subject.lastCollider) and not Util.isItem(subject.lastCollider) and
				subject.lastCollisionPos.y > 770):
				var impulse = acceleration * subject.totalWeight
				if impulse > 2000:
					Game.STORAGEBOX.shake(subject.lastCollisionPos, true)
				elif impulse > 800:
					Game.STORAGEBOX.shake(subject.lastCollisionPos, false)

			particles.scale = Vector2(0.3, 0.3) * sqrt(subject.getNumCells()) + Vector2(0.1, 0.1)

		subject.lastVelocity = curVelocity

static func rotateTo(subject: Receiver, targetRotation, duration):
	subject.rotationTween = Util.refreshTween(subject.rotationTween)
	subject.rotationTween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	var curRotation = subject.sprite.global_rotation
	subject.global_rotation = targetRotation
	subject.faceDirection = subject.getGlobalFaceDirection()
	subject.sprite.global_rotation = curRotation
	subject.updateInsideRotationNode()

	subject.rotationTween.tween_method(Callable(subject, "lerpAngle_local").bindv([subject.sprite.rotation, 0.0]), 0.0, 1.0, duration)

	subject.updateShaderRotation()
	subject.updateShadow()

	if subject.isMovingBack():
		subject.rotationTween.tween_callback(Callable(subject, "reparentItemsInside"))
	else:
		subject.rotationTween.tween_callback(Callable(subject, "correctInsideItemFacedirection"))

	subject.call_deferred("rotateToDeferred", targetRotation)

static func respondToHover(subject: Receiver):
	if subject.hoverResponseEnabled and Game.hoverResponseEnabled():
		if ( not subject.isBag() or subject.ownerType == subject.Owner.Shop) and Engine.time_scale > 0:

			var particles = subject.createParticles(subject.hoverSparksScene, Vector2(0.7, 0.7))
			particles.modulate = Game.rarityColors[subject.getRarity()].lightened(0.2)

			Sound.playSound_process(subject.hoverSound, 0, Util.rng.randf_range(0.9, 1.2))

			if subject.dragParticlesEnabled:
				subject.activateDragParticles()

		subject.setBright()
		subject.previewFusions()

		if subject.isOwnable() or subject.isOwnedByOpponent():
			if subject.has_method("canAffect_global"):
				var inv = subject.inventory if subject.inventory != null else Game.PLAYER.INVENTORY
				for item in inv.getItems():
					if subject.me.canAffect_global(item):
						var visual = ObjectPool.instantiate(subject.globalAffectVisual)
						subject.globalAffectVisuals.push_back(visual)
						item.add_child(visual)

	if not Game.tooltipsEnabled():
		return

	if subject.ownerType == subject.Owner.Shop:
		if not subject.dragged:
			subject.previewCells()
		subject.z_index = max(subject.z_index, 2)
		for shadow in subject.shadows:
			shadow.z_index = - 2

	elif subject.ownerType == subject.Owner.RecipeBook or subject.ownerType == subject.Owner.ItemLibrary:
		subject.z_index = max(subject.z_index, 2)
		subject.previewCells()

	if subject.ownerType == subject.Owner.ItemLibrary:
		subject.showSockets()

	if subject.tooltipEnabled:
		if not subject.tooltip and not subject.dragged:
			if subject.ownerType == subject.Owner.RecipeBook:
				subject.tooltipMargin.x = 60

			var texSize = Util.absv((subject.sprite.global_scale * subject.sprite.texture.get_size()).rotated(subject.rotation))
			var tooltipPos = subject.global_position - texSize * 0.5 - subject.tooltipMargin * 0.5
			var toolsize = subject.tooltipMargin

			var ownerType_ = subject.getEffectiveOwnerType()
			var inventory_ = subject.getInventory()

			match ownerType_:
				subject.Owner.Shop:
					tooltipPos.x = 550

				subject.Owner.PlayerInventory:
					tooltipPos.x = inventory_.getRightBorder() + 30

				subject.Owner.PlayerStorageBox:
					tooltipPos.x = 1800

				subject.Owner.GridStorage:
					tooltipPos.x = 1800

				subject.Owner.Opponent:
					tooltipPos.x = inventory_.getLeftBorder() - 700

				subject.Owner.RecipeBook:
					toolsize += texSize

				subject.Owner.ItemLibrary:
					tooltipPos.x = 1950

				subject.Owner.BuildViewer:
					var leftBorder = inventory_.getLeftBorder()
					if leftBorder > 800:
						tooltipPos.x = leftBorder - 700
					else:
						tooltipPos.x = 450

				subject.Owner.BuildViewerIcon:
					tooltipPos.x -= 50
					toolsize.x += 100

				subject.Owner.Tooltip:
					if subject.owningBuildIntoRecipesTooltip != null:
						match Game.lockedTooltipItem.getEffectiveOwnerType():
							subject.Owner.Shop:
								tooltipPos.x = 610
							subject.Owner.PlayerInventory:
								tooltipPos.x = Game.lockedTooltipItem.tooltip.position.x - 108
							subject.Owner.PlayerStorageBox:
								tooltipPos.x = 610
							subject.Owner.ItemLibrary:
								toolsize.x += 50
					else:
						tooltipPos.x -= 50
						toolsize.x += 150

			if subject.ownerType != subject.Owner.RecipeBook:

				subject.tooltip = ObjectPool.instantiate(subject.tooltipScenes[subject.getRarity()])
			else:
				subject.tooltip = subject.recipeTooltip.instantiate()

			Game.tooltipsNode.add_child(subject.tooltip)
			subject.tooltip.setItem(subject)
			subject.tooltip.forceUpdatePosition(tooltipPos, toolsize)

			if Game.showHintsIsPressed:
				if subject.isOwnable() or subject.isOwnedByOpponent():
					subject.previewCanAffect()
				Game.clearAffectedLines()

				if (Game.RECIPE_TOOLTIPS_ENABLED and
					subject.canShowBuildIntoRecipesTooltip()):

					subject.showBuildIntoRecipesTooltip()

static func canShowBuildIntoRecipesTooltip(subject: Receiver) -> bool:
	if subject.dragged: return false

	var effectiveOwner = subject.getEffectiveOwnerType()

	if subject.ownerType == subject.Owner.Tooltip and subject.owningBuildIntoRecipesTooltip != null:
		if not subject.canShowSubBuildIntoRecipesTooltip():
			return false
	elif not (subject.ownerType == subject.Owner.Shop or
			subject.ownerType == subject.Owner.ItemLibrary or
			effectiveOwner in subject.ownerTypesWithBuildTooltip):
		return false

	var descr = subject.getRecipeDescriptor()
	if descr.getNumRecipes() > 0:
		return true

	if subject.getRelatedItems().size() > 0:
		return true

	return false

static func showBuildIntoRecipesTooltip(subject: Receiver):
	if subject.pve_is_view(): return
	if subject.buildIntoRecipesTooltip != null: return

	var descr = subject.getRecipeDescriptor()
	if (descr.getNumRecipes() > 0 or
		subject.getRelatedItems().size() > 0):

		subject.buildIntoRecipesTooltip = subject.buildIntoRecipesTooltipScene.instantiate()

		if subject.ownerType == subject.Owner.Tooltip:
			Game.tooltipsNode.add_child(subject.buildIntoRecipesTooltip)
		else:
			Game.recipeTooltipsNode.add_child(subject.buildIntoRecipesTooltip)

		var ownerType_ = subject.getEffectiveOwnerType()
		var inventory_ = subject.getInventory()

		var tooltipPos = Vector2(0, 0)

		match ownerType_:
			subject.Owner.Shop:
				tooltipPos.x = 180
				subject.buildIntoRecipesTooltip.growToRight = false

			subject.Owner.PlayerInventory:
				tooltipPos.x = inventory_.getRightBorder() + 680
				subject.buildIntoRecipesTooltip.growToRight = true

			subject.Owner.PlayerStorageBox:
				tooltipPos.x = 260
				subject.buildIntoRecipesTooltip.growToRight = false

			subject.Owner.ItemLibrary:

				if subject.position.x < 900:
					tooltipPos.x = 870
					subject.buildIntoRecipesTooltip.growToRight = false
				else:
					tooltipPos.x = 0
					subject.buildIntoRecipesTooltip.growToRight = true

			subject.Owner.Opponent:
				tooltipPos.x = inventory_.getLeftBorder() - 1080
				subject.buildIntoRecipesTooltip.growToRight = false

			subject.Owner.BuildViewer:
				tooltipPos.x = inventory_.getLeftBorder() - 1080
				subject.buildIntoRecipesTooltip.growToRight = false

			subject.Owner.GridStorage:
				tooltipPos.x = 260
				subject.buildIntoRecipesTooltip.growToRight = false

			subject.Owner.Tooltip:
				match Game.lockedTooltipItem.getEffectiveOwnerType():
					subject.Owner.Shop:
						tooltipPos.x = 1250
						subject.buildIntoRecipesTooltip.growToRight = true
					subject.Owner.PlayerInventory:
						tooltipPos.x = Game.lockedTooltipItem.getInventory().getRightBorder() - 350
						if tooltipPos.x < - 100:
							tooltipPos.x = subject.owningBuildIntoRecipesTooltip.position.x + subject.owningBuildIntoRecipesTooltip.size.x - 50
							subject.buildIntoRecipesTooltip.growToRight = true
						else:
							subject.buildIntoRecipesTooltip.growToRight = false
					subject.Owner.PlayerStorageBox:
						tooltipPos.x = 1250
						subject.buildIntoRecipesTooltip.growToRight = true

		subject.buildIntoRecipesTooltip.position = tooltipPos
		subject.buildIntoRecipesTooltip.setItem(subject, ownerType_ == subject.Owner.Tooltip)

		var recipeTop = subject.buildIntoRecipesTooltip.position.y

		var recipeCenter = recipeTop + 0.5 * subject.buildIntoRecipesTooltip.size.y
		var tooltipCenter = subject.tooltip.position.y + 0.5 * subject.tooltip.size.y

		var targetTop
		if subject.spotlight:
			targetTop = Game.itemLibrary.SPOTLIGHT_POS.y - 0.5 * subject.buildIntoRecipesTooltip.size.y
		else:
			targetTop = recipeTop + tooltipCenter - recipeCenter

		targetTop = max(0, targetTop)

		var bottom = targetTop + subject.buildIntoRecipesTooltip.size.y
		if bottom > 1100:
			targetTop -= bottom - 1100

		subject.buildIntoRecipesTooltip.position.y = targetTop

		Game.setTutorialDone(Game.TutorialSteps.ShowRecipes)

static func respondToHoverEnd(subject: Receiver):
	subject.collisionMap.hide()
	if subject.tooltipEnabled:

		subject.resetBright()
		if Game.showHintsIsPressed:
			Game.showAffectedLines()
		if Game.lockedTooltipItem != subject:
			subject.clearTooltip()

	CraftingManager.hideFusionPreviews(subject.isMovingBack())
	Game.combatLog.unhighlightItem(false)

	if subject.dragParticlesEnabled:
		subject.deactivateDragParticles()

	for visual in subject.globalAffectVisuals:
		ObjectPool.returnInstance(visual)
	subject.globalAffectVisuals.clear()

	if subject.ownerType == subject.Owner.Shop:
		subject.resetZ()
		for shadow in subject.shadows:
			shadow.z_index = - 1
	elif subject.ownerType == subject.Owner.RecipeBook or subject.ownerType == subject.Owner.ItemLibrary:
		subject.resetZ()

	if subject.ownerType == subject.Owner.ItemLibrary:
		subject.hideSockets()

static func hover(subject: Receiver):

	if subject.hovered_state:

		return

	if not subject.tooltipEnabled: return
	if InputBlocker.isActive(): return

	if Game.lockedTooltipItem != null:
		if Game.lockedTooltipItem.buildIntoRecipesTooltip != subject.owningBuildIntoRecipesTooltip:
			return
		if Game.lockedTooltipItem.isA(subject.descriptor):
			return

	if subject.spotlight: return

	if (Game.state == Game.State.Shop and
		Game.isMenuOpen() and
		not subject.ownerType in subject.hoverableWhenMenuOpen):
		return

	subject.hovered_state = true

	Game.itemHovered(subject)
	if Game.hasHoverFocus(subject):
		subject.gainFocus()

	subject.emit_signal("hovered")

static func pickup(subject: Receiver, pickupType):
	var pve_inside: Array = []
	if subject.pve_is_view():
		subject.set_meta("pve_drag_layout", true)
		Expedition.bridge.fit_native_visual(subject, false)
		subject.set_meta("pve_grid_navigation", false)
		if subject.isBag() and subject.ownerType == subject.Owner.PlayerInventory:
			pve_inside = Expedition.bridge.bag_contents(subject)

	subject.pickupFrame = Util.frameCounter
	subject.resetSprite()

	if subject.ownerType == subject.Owner.Shop:
		Util.reparentNode(subject, Game.playerNode)
		subject.collisionMap.hide()

	elif subject.ownerType == subject.Owner.PlayerStorageBox:
		Util.reparentNode(subject, Game.playerNode)

		if subject.isInGridStorage():
			subject.setFaceDirectionInstant(subject.FaceDirection.UP)
		else:
			subject.setFaceDirection(subject.FaceDirection.UP)
		subject.onStorageLeft()

	elif subject.inventory != null and subject.ownerType == subject.Owner.PlayerInventory:
		subject.pickupTopLeftCell = subject.getTopLeftCell()
		subject.pickupFaceDirection = subject.getFaceDirection()

		subject.inventory.removeItem(subject)
		subject.setBright()
		if pickupType == subject.PickupType.MultiSelect:
			subject.draggedInsideItems = subject.inventory.getMultiSelectItems()
			for item in subject.draggedInsideItems:
				if item.draggingParent:

					item.draggingParent.finishMoveback()

				item.onDraggedWithParentStart(subject)

				subject.inventory.removeItem(item)
				Util.reparentNode(item, subject.insideRotationNode)
				item.resetBright()

		elif subject.isBag():
			var hotswapBagWithDraggedItems = not Settings.getVal(Settings.Setting.bag_hotswapping)
			if Game.hotswapBehaviorModified:
				hotswapBagWithDraggedItems = not hotswapBagWithDraggedItems

			if (Game.inventoryEditMode == Game.InventoryEditMode.Default and
				(pickupType == subject.PickupType.Grabbed or hotswapBagWithDraggedItems)):
				if subject.draggingParent == null:
					subject.draggedInsideItems = pve_inside if subject.pve_is_view() else subject.me.getItemsInside()
					for item in subject.draggedInsideItems:
						if item.draggingParent:

							item.draggingParent.finishMoveback()

						item.onDraggedWithParentStart(subject)

						subject.inventory.removeItem(item)
						Util.reparentNode(item, subject.insideRotationNode)

	Game.itemPickedUp(subject)
	subject.dragged = true
	subject.clearTooltip()
	Sound.playSound(subject.grabSound, - 12)
	subject.playPickupSound()
	Sound.itemMovePlayer.play()
	Sound.itemMovePlayer.pitch_scale = 1.3 - 0.1 * subject.getNumCells()

	for shadow in subject.shadows:
		shadow.z_index = - 1
	Util.killTween(subject.shadowTween)
	subject.shadowTween = subject.create_tween().set_parallel(true)
	subject.shadowTween.tween_property(subject, "shadowOffset", subject.shadowOffset_dragged, 0.1)
	if not subject.isBag():
		subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale * 1.1, 0.1)

	subject.z_index = 20

	if not subject.isMovingBack():
		subject.pickupPosition = subject.global_position
		subject.pickupRotation = fmod(subject.global_rotation + 2 * PI, 2 * PI)
	else:
		subject.killMovebackTween()

	subject.previewFusions()

	InputBlocker.disableAllControls(InputBlocker.Source.ItemDragging, Game.mainNode)

	subject.emit_signal("picked_up")

static func reactToDropResult(subject: Receiver, result):
	if result == subject.DropResult.Failed:
		subject.dragged = true
		return

	subject.dragged = false
	subject.dropFrame = Util.frameCounter
	Util.killTween(subject.shadowTween)
	subject.shadowTween = subject.create_tween().set_parallel(true)
	subject.shadowTween.tween_property(subject, "shadowOffset", subject.getShadowOffset(), 0.1)
	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale, 0.1)
	for shadow in subject.shadows:
		subject.shadowTween.tween_property(shadow, "scale", subject.spriteScale, 0.1)

	Game.itemDropped(subject, result)

	subject.loseFocus()
	Game.recalcHoverPriority()

	subject.playDropSound()
	Sound.itemMovePlayer.stop()

	subject.sprite.rotation = 0
	subject.bonusRotation = 0
	subject.rotationMomentum = 0

	subject.createParticles(subject.dropParticlesScene, Vector2(0.6, 0.6))
	subject.dragParticles.deactivate()

	if result != subject.DropResult.Hotswap:
		InputBlocker.restoreAllControls(InputBlocker.Source.ItemDragging)

	subject.emit_signal("dropped", result)

static func drop(subject: Receiver) -> int:
	if subject.pve_is_view(): return Expedition.bridge.drop_item(subject)
	var previousOwnerType = subject.ownerType
	var result = 0
	subject.dragged = false
	subject.resetSprite()

	if Game.STORAGEBOX.isHovered():
		subject.lastCollisionPos = subject.global_position
		subject.addToStorageBox()
		result = subject.DropResult.AddedToStorageBox
		if not subject.draggedInsideItems.is_empty():
			Game.STORAGEBOX.pushItemsToStorage(subject.draggedInsideItems)
			subject.clearDraggedInsideItems()

	elif Game.SELLBOX.isHovered():
		subject.sold = true
		result = subject.DropResult.Sold
		subject.onSold()
		subject.animation.play("Sell")
		ItemBook.onOwnableItemRemoved(subject)
		subject.prepareDiscard()

		subject.clickArea.hide()

		subject.pushGemsToStorage()
		Game.SELLBOX.sellItem(subject)
		Game.itemHoverEnd(subject)
		if not subject.draggedInsideItems.is_empty():
			Game.STORAGEBOX.pushItemsToStorage(subject.draggedInsideItems)
			subject.clearDraggedInsideItems()
	else:

		subject.finishInsideItemsRotation()

		result = Game.PLAYER.INVENTORY.tryAddItem(subject)
		if subject.wasAddedToInventory(result):
			subject.dropIntoInventory(result == subject.DropResult.Hotswap)
		else:

			if (subject.ownerType == subject.Owner.PlayerInventory and
				subject.isBag() and
				not subject.inventory.allCellsPotentialSpace(subject.occupiedCells)):

				subject.pushDraggedItemsToStorage()
				subject.pushToStorage()
				return subject.DropResult.AddedToStorageBox

			var dif = (subject.pickupPosition - subject.global_position)
			var movebackDur = clamp(dif.length() / 1000, 0.1, 0.5)

			subject.killMovebackTween()

			var curPosition = subject.global_position
			var insidePositions = []
			for item in subject.draggedInsideItems:
				insidePositions.push_back(item.global_position)

			if Game.state == Game.State.Shop and subject.ownerType == subject.Owner.PlayerInventory:

				if not subject.draggedInsideItems.is_empty():

					for itemI in subject.draggedInsideItems.size():
						var item = subject.draggedInsideItems[itemI]
						Util.reparentNode(item, Game.playerNode)
						var insideRes = subject.inventory.tryAddItem(item, false)

						if not subject.wasAddedToInventory(insideRes):
							item.global_position = insidePositions[itemI]
							item.pushToStorage()

					subject.correctInsideItemFacedirection()
					subject.clearDraggedInsideItems()

					subject.pickup(subject.PickupType.Hotswap)

					return subject.DropResult.Failed
				else:
					subject.pushToStorage()
					return subject.DropResult.AddedToStorageBox

			subject.ownerType = previousOwnerType

			if subject.ownerType == subject.Owner.Socket:
				subject.returnToSocket(movebackDur)
			else:
				subject.clickArea.hide()
				subject.movebackTween = subject.create_tween()

				subject.global_position = subject.pickupPosition
				subject.rotateTo(subject.pickupRotation, movebackDur)

				if subject.ownerType == subject.Owner.PlayerInventory:
					result = subject.inventory.tryAddItem(subject)

					if not subject.wasAddedToInventory(result):
						subject.global_position = curPosition

						subject.pushToStorage()
						return subject.DropResult.AddedToStorageBox

					if not subject.draggedInsideItems.is_empty():
						for itemI in subject.draggedInsideItems.size():
							var item = subject.draggedInsideItems[itemI]
							var insideRes = subject.inventory.tryAddItem(item)
							if not subject.wasAddedToInventory(insideRes):
								item.global_position = insidePositions[itemI]
								item.pushToStorage()

				subject.global_position = curPosition
				subject.movebackTween.tween_property(subject, "global_position", subject.pickupPosition,
					movebackDur).set_ease(Tween.EASE_IN)

				if subject.ownerType == subject.Owner.PlayerStorageBox:
					Game.STORAGEBOX.addItem(subject)
					Util.reparentNode(subject, Game.STORAGEBOX)

					subject.movebackTween.tween_callback(Callable(subject, "moveToFreeSpaceInStorage").bind())
					subject.movebackTween.tween_callback(Callable(subject, "apply_impulse").bindv([
						Vector2(0, - 3), dif * 1.0,
					]))

				if subject.ownerType == subject.Owner.Shop:
					Util.reparentNode(subject, Game.shopItemYSort)

				subject.set_deferred("z_index", 32)
				subject.movebackTween.tween_callback(Callable(subject, "resetZ"))
				subject.movebackTween.tween_callback(Callable(subject, "showClickArea"))

	subject.sameOrientationAsPickup = true
	if previousOwnerType != subject.ownerType:
		subject.sameOrientationAsPickup = false
	elif subject.ownerType == subject.Owner.PlayerInventory:
		if subject.getFaceDirection() != subject.pickupFaceDirection:
			subject.sameOrientationAsPickup = false
		if subject.getTopLeftCell() != subject.pickupTopLeftCell:
			subject.sameOrientationAsPickup = false

	return result

static func cancelDrag(subject: Receiver):
	if subject.pve_is_view():
		Expedition.bridge.cancel_drag(subject)
		return
	var movebackDur = 0.2

	match subject.ownerType:
		subject.Owner.PlayerInventory:
			var insideStartPositions = {}
			for item in subject.draggedInsideItems:
				insideStartPositions[item] = item.global_position

			subject.finishInsideItemsRotation()
			var curTransform: Transform2D = subject.get_global_transform()
			subject.inventory.orientItem(subject, subject.pickupTopLeftCell, subject.pickupFaceDirection)
			if subject.inventory.canAddItemOrBag(subject):
				subject.inventory.addItemByTopLeft(subject, subject.pickupTopLeftCell)

				subject.dropIntoInventory(false)

				subject.set_global_transform(curTransform)
				subject.moveTo(subject.global_position, subject.pickupPosition, movebackDur)
				subject.rotateTo(subject.pickupRotation, movebackDur)

				for item in insideStartPositions:
					item.moveTo(insideStartPositions[item], item.global_position, movebackDur)

				subject.reactToDropResult(subject.DropResult.AddedToInventory)
			else:

				subject.set_global_transform(curTransform)
				subject.pushDraggedItemsToStorage()
				subject.addToStorageBox(false, false, true)
				subject.reactToDropResult(subject.DropResult.AddedToStorageBox)

		subject.Owner.PlayerStorageBox:
			subject.addToStorageBox(false, false, true)
			subject.reactToDropResult(subject.DropResult.AddedToStorageBox)

		subject.Owner.Shop:
			subject.moveTo(subject.global_position, subject.pickupPosition, movebackDur)
			subject.rotateTo(subject.pickupRotation, movebackDur)
			Util.reparentNode(subject, Game.shopItemYSort)
			subject.reactToDropResult(subject.DropResult.OutsideInventory)

		subject.Owner.Socket:
			if subject.movebackSocket != null:
				if subject.movebackSocket.isEmpty():
					subject.returnToSocket(movebackDur)
					subject.reactToDropResult(subject.DropResult.Socketed)
				else:
					subject.addToStorageBox(false, false, true)
					subject.reactToDropResult(subject.DropResult.AddedToStorageBox)

static func dropIntoInventory(subject: Receiver, hotswap):
	subject.resetZ()
	var hotswapped = hotswap

	for item in subject.draggedInsideItems:
		if subject.inventory.canAddItemOrBag(item):

			Util.reparentNode(item, Game.playerNode)
			subject.correctInsideItemFacedirection()
			var res = subject.inventory.tryAddItem(item)

		else:

			if not hotswapped:
				Util.reparentNode(item, Game.playerNode)

				item.pickup(subject.PickupType.Hotswap)
				hotswapped = true
			else:
				item.pushToStorage()
	subject.clearDraggedInsideItems()

	if hotswapped:
		subject.resetBright()

	for color in subject.Affected.values():
		var affectedPoints = subject.inventory.getAffectedPoints(subject, color)
		for point in affectedPoints:
			var star = ObjectPool.instantiate(subject.affectedAnis[color])
			Game.playerNode.add_child(star)
			star.global_position = point
		if affectedPoints.size() > 0:

			Sound.playSound(subject.affectedSounds[color], subject.affectedSoundsVolume[color], 0.9 + 0.05 * affectedPoints.size())
