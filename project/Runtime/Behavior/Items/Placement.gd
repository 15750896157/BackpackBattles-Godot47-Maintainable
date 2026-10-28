extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func addToInventory(subject: Receiver, _inventory, _occupiedCells: Array, _placedByPlayer: bool):
	if subject.pve_is_view():
		subject.placedByPlayer = _placedByPlayer
		subject.placed = true
		subject.inventory = _inventory
		subject.occupiedCells = _occupiedCells
		subject.makeGrabbable(false)
		subject.set_physics_process(false)
		return

	subject.placedByPlayer = _placedByPlayer
	subject.placed = true
	subject.inventory = _inventory
	subject.occupiedCells = _occupiedCells
	if subject.ownerType != subject.Owner.BuildViewer:
		if subject.inventory == Game.PLAYER.INVENTORY:
			subject.ownerType = subject.Owner.PlayerInventory
		elif subject.inventory == Game.OPPONENT.INVENTORY:
			subject.ownerType = subject.Owner.Opponent

	subject.inventory.connect("item_added", Callable(subject, "onItemAdded"))
	subject.inventory.connect("item_removed", Callable(subject, "onItemRemoved"))
	subject.inventory.connect("item_type_changed", Callable(subject, "onItemTypeChanged"))

	if subject.ownerType != subject.Owner.BuildViewer:
		CraftingManager.itemAdded(subject)
		for gem in subject.getGemsNoNull():
			CraftingManager.itemAdded(gem)

	subject.cacheAffectedCells()

	for color in subject.Affected.values():
		for item in subject.getAffectedItems(color):
			subject.currentAffectedItems[color][item] = true
			subject.onAffectedItemAdded(item, color)

	subject.makeGrabbable(false)

	subject.onAddToInventory()

	if subject.ownerType == subject.Owner.PlayerInventory:
		if subject.has_method("getGatedDescriptor"):
			Game.shopSceneNode.connect("gate_item_roll", Callable(subject, "onGateItemRoll"))
		Util.connectIfExists(Game.shopSceneNode, "roll_sale", subject, "onSaleRoll")
		Util.connectIfExists(ItemBook, "pre_item_roll", subject, "onItemRoll")
		Util.connectIfExists(ItemBook, "item_rolled", subject, "onItemRolled")
		Util.connectIfExists(ItemBook, "items_counted", subject, "onItemsCounted")
		Util.connectIfExists(Game.SELLBOX, "calc_trade_chance", subject, "onCalcTradeChance")

	subject.emit_signal("added_to_inventory")

static func removeFromInventory(subject: Receiver):
	if subject.pve_is_view():
		subject.placed = false
		subject.occupiedCells.clear()
		return
	if not subject.placed: return

	subject.placed = false

	CraftingManager.itemRemoved(subject)
	for gem in subject.getGemsNoNull():
		CraftingManager.itemRemoved(gem)

	subject.inventory.disconnect("item_added", Callable(subject, "onItemAdded"))
	subject.inventory.disconnect("item_removed", Callable(subject, "onItemRemoved"))
	subject.inventory.disconnect("item_type_changed", Callable(subject, "onItemTypeChanged"))

	for color in subject.Affected.values():
		for item in subject.currentAffectedItems[color]:
			subject.onAffectedItemRemoved(item, color)

	subject.cleanCachedAffectedItems()

	subject.onRemoveFromInventory()

	Util.tryDisconnect(Game.shopSceneNode, "gate_item_roll", subject, "onGateItemRoll")
	Util.tryDisconnect(Game.shopSceneNode, "roll_sale", subject, "onSaleRoll")
	Util.tryDisconnect(ItemBook, "pre_item_roll", subject, "onItemRoll")
	Util.tryDisconnect(ItemBook, "item_rolled", subject, "onItemRolled")
	Util.tryDisconnect(ItemBook, "items_counted", subject, "onItemsCounted")
	Util.tryDisconnect(Game.SELLBOX, "calc_trade_chance", subject, "onCalcTradeChance")

static func playAffectedPlacedAnimation(subject: Receiver, newItemIsAffected: Dictionary):
	var sum = 0
	for color in newItemIsAffected:
		sum += int(newItemIsAffected[color])

	if sum > 1:
		subject.animation.play("AffectedPlaced")
	elif newItemIsAffected[subject.Affected.Primary]:
		subject.animation.play("AffectedPlaced_Primary")
	elif newItemIsAffected[subject.Affected.Secondary]:
		subject.animation.play("AffectedPlaced_Secondary")
	elif newItemIsAffected[subject.Affected.Tertiary]:
		subject.animation.play("AffectedPlaced_Tertiary")
	elif newItemIsAffected[subject.Affected.Lightning]:
		subject.animation.play("AffectedPlaced_Lightning")

static func onItemAdded(subject: Receiver, item):

	var newItemIsAffected = {}
	for color in subject.Affected.values():
		newItemIsAffected[color] = ( not item in subject.currentAffectedItems[color] and
									subject.isItemAffected(item, color))

	if item.placedByPlayer:
		subject.playAffectedPlacedAnimation(newItemIsAffected)

	for color in subject.Affected.values():
		if newItemIsAffected[color]:
			subject.currentAffectedItems[color][item] = true
			subject.onAffectedItemAdded(item, color)

static func onItemTypeChanged(subject: Receiver, item):

	var canAddAgain = subject.reactToItemTypeChange(item)

	if not canAddAgain:
		return

	var addedToAffected = {}
	for color in subject.Affected.values():
		addedToAffected[color] = false

		if item in subject.currentAffectedItems[color]:

			if not subject.canAffect_color(item, color):
				subject.currentAffectedItems[color].erase(item)
				subject.onAffectedItemRemoved(item, color)
		elif item in subject.getAffectedItems(color):
			subject.currentAffectedItems[color][item] = true
			subject.onAffectedItemAdded(item, color)
			addedToAffected[color] = true

	if item.placedByPlayer:
		subject.playAffectedPlacedAnimation(addedToAffected)

static func previewCanAffect(subject: Receiver):
	var visuals = {}

	var itemDict
	if subject.ownerType == subject.Owner.Opponent:
		itemDict = ItemBook.opponentItems
	else:
		itemDict = ItemBook.ownableItems

	for color in subject.Affected.values():
		var curAffected = subject.getAffectedItems(color)

		for descr in itemDict:
			for item in itemDict[descr]:
				if (item != subject and
					not item.isBag() and
					( not item.isGem() or item.socket == null)
					and subject.canAffect_color(item, color)
					and not item in curAffected):

					var visual = visuals.get(item, null)
					if visual == null:
						visual = ObjectPool.instantiate(subject.canAffectVisual)
						item.add_child(visual)

						subject.canAffectVisuals.push_back(visual)
						visuals[item] = visual
					visual.setColorActive(color)

static func addToStorageBox(subject: Receiver, addImpulse, tweenBouncyness: bool, checkCollisions, targetPos, speed, secondCheck):
	if subject.pve_is_view():
		Expedition.bridge.store_item(subject)
		return

	subject.ownerType = subject.Owner.PlayerStorageBox
	Game.STORAGEBOX.addItem(subject)
	subject.occupiedCells.clear()
	Util.reparentNode(subject, Game.STORAGEBOX)
	for particles in subject.specificDragParticles:
		if particles is GPUParticles2D:
			particles.set_visibility_rect(Rect2( - 2000, - 2000, 4000, 4000))

	Util.killTween(subject.rotationTween)
	subject.rotation += subject.sprite.rotation
	subject.sprite.rotation = 0

	if not tweenBouncyness:
		subject.physics_material_override.bounce = 0.0
		subject.physics_material_override.friction = 1.0

	if checkCollisions:

		subject.moveToFreeSpaceInStorage(targetPos, addImpulse, speed, secondCheck, tweenBouncyness)
	else:
		if subject.mode != 0:
			subject.makeRigidBody()

	subject.makeGrabbable(true)

	Util.connectIfExists(Game.shopSceneNode, "roll_sale", subject, "onSaleRoll_storage")
	Util.connectIfExists(Game.shopSceneNode, "gate_item_roll", subject, "onGateItemRoll_storage")

	subject.onAddedToStorageBox()

static func moveToFreeSpaceInStorage(subject: Receiver, targetPos, addImpulse, speed, secondCheck, tweenBouncyness: bool):

	subject.resetSprite()

	targetPos = Util.clampToRect(targetPos, Game.STORAGEBOX.getStorageRect())
	var freePos = subject.findFreeSpace(targetPos)
	var dif = freePos - subject.global_position
	var length = dif.length()
	if length > 50:
		var dur: float = length * 0.001 / (speed * Util.rng.randf_range(0.8, 1.2))
		dur = clamp(dur, 0.1, 0.5)
		subject.killMovebackTween()
		subject.movebackTween = subject.create_tween()
		subject.movebackTween.tween_property(subject, "global_position", freePos, dur)
		subject.movebackTween.tween_callback(Callable(subject, "makeRigidBody"))
		subject.movebackTween.tween_callback(Callable(subject, "resetZ"))

		if subject.isGem():
			subject.set_deferred("z_index", 34)
		elif subject.isBag():
			subject.set_deferred("z_index", 32)
		else:
			subject.set_deferred("z_index", 33)

		if addImpulse:
			subject.movebackTween.tween_callback(Callable(subject, "dropImpulse").bind(dif, tweenBouncyness))

		if secondCheck:
			subject.movebackTween.tween_callback(Callable(subject, "moveToFreeSpaceInStorage").bindv([targetPos, addImpulse, speed, false]))
		else:
			subject.movebackTween.tween_callback(Callable(subject, "checkIfOutofStorageBounds"))
	else:
		subject.resetZ()
		subject.global_position = freePos
		subject.makeRigidBody()
		if addImpulse:
			subject.dropImpulse(null, tweenBouncyness)

static func findFreeSpace(subject: Receiver, startPos: Vector2) -> Vector2:
	var spaceState = subject.get_world_2d().get_direct_space_state()
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var shape

	if subject.collisionShape is CollisionShape2D:
		shape = subject.collisionShape.shape
	else:

		shape = ConvexPolygonShape2D.new()
		shape.points = Geometry2D.convex_hull(subject.collisionShape.polygon)

	query.set_shape(shape)
	query.collide_with_bodies = true
	if subject.ownerType == subject.Owner.Title:
		query.collision_mask = 4 + 1
	else:
		query.collision_mask = 1
	query.collide_with_areas = false
	query.transform = subject.get_global_transform()
	query.exclude = [subject]
	query.transform.origin = startPos
	var freePos = startPos
	var initialCollisions = spaceState.collide_shape(query, 1)
	if initialCollisions.is_empty():
		return freePos

	var tries = 0

	for offset in [20, 40, 70, 100, 150, 200, 250, 300, 400, 500, 600]:
		for angle in range(subject.angleStep, 360 + subject.angleStep, subject.angleStep):
			freePos = startPos + (Vector2.UP * offset).rotated(deg_to_rad(angle))
			query.transform.origin = freePos
			var collisions = spaceState.collide_shape(query, 1)

			tries += 1
			if collisions.is_empty():

				return freePos

	return freePos
