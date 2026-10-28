extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func considerAsBond(subject: Receiver, neighbor):
	var score = 0.0
	var recipe = null
	if subject.curRecipe:
		if subject.isRecipeFinished():
			return null

		if subject.curRecipe.checkNeighbor(subject.bondedIngredients, neighbor):
			var progressBefore = subject.curRecipe.getProgress(subject.bondedIngredients)
			var progressWithNeighbor = (subject.bondedIngredients.size() + 1) / float(subject.curRecipe.getNumIngredients())
			score = progressWithNeighbor + 0.1 * progressBefore
			recipe = subject.curRecipe
	else:
		var bestScore = 0.0
		for r in subject.getRecipes():
			if r.checkNeighbor([], neighbor):
				var s = 1.0 / r.getNumIngredients()
				if s > bestScore:
					bestScore = s
					recipe = r

		score = bestScore

	if recipe:
		return [recipe, score]
	else:
		return null

static func playBondAnimation(subject: Receiver):
	subject.animation.advance(10)

	var catalyst = false
	if subject.bondedBaseItem != null:
		if subject.bondedBaseItem.curRecipe != null:
			catalyst = subject.bondedBaseItem.curRecipe.isCatalystRecipe()
	else:
		if subject.curRecipe != null:
			catalyst = subject.curRecipe.isCatalystRecipe()

	if catalyst:
		subject.animation.play("CatalystBondCreated")
	else:
		subject.animation.play("BondCreated")

static func showLockLabel(subject: Receiver):
	var label = ObjectPool.instantiate(subject.lockLabelScene)
	Game.labelsNode.add_child(label)
	if subject.locked:
		false # label.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	else:
		false # label.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed

	label.global_position = Util.clampToScreen(subject.global_position
		+ label.label.position) - label.label.position

static func previewRecipeIngredients(subject: Receiver):
	var ingredients = Dictionary()
	var nonDescriptorIngredients = Array()

	for recipe in subject.getRecipes(false):
		for ingredient in recipe.ingredients:
			if Util.isItemDescriptor(ingredient):
				ingredients[ingredient] = true
			else:
				nonDescriptorIngredients.push_back(ingredient)

	if ingredients.is_empty() and nonDescriptorIngredients.is_empty(): return

	var candidateItems = ItemBook.getInventoryStorageShopItems()

	for candidate in candidateItems:
		if candidate != subject and (candidate.descriptor in ingredients
				or subject.typeInIngredients(candidate, nonDescriptorIngredients)):
			if ( not candidate in subject.bondedIngredients and
				not subject in candidate.bondedIngredients):
				CraftingManager.call_deferred("createFusionPreview",
					subject, candidate, subject.getGridStorageProxy())

static func hasShopItemCraftCandidates(subject: Receiver) -> bool:
	if subject.pve_is_view(): return false

	var candidates: Array = ItemBook.getInventoryStorageShopItems()

	var ingredients = Dictionary()
	var nonDescriptorIngredients = Array()

	for recipe in subject.getRecipes(false):
		for ingredient in recipe.ingredients:
			if Util.isItemDescriptor(ingredient):
				ingredients[ingredient] = true
			else:
				nonDescriptorIngredients.push_back(ingredient)

	if not ingredients.is_empty() or not nonDescriptorIngredients.is_empty():
		for candidate in candidates:
			if candidate != subject and (candidate.descriptor in ingredients
					or subject.typeInIngredients(candidate, nonDescriptorIngredients)):
				return true

	for item in candidates:
		if item != subject and item.isBaseItemForShopItem(subject):
			return true

	return false

static func showProgressLabel(subject: Receiver):
	if not subject.curRecipe: return

	var curNum = subject.bondedIngredients.size() + 1
	if curNum == 1:
		if subject.craftingLabel:
			subject.craftingLabel.fade()
		return

	var outOf = subject.curRecipe.getNumIngredients() + 1
	var fusionName = subject.getFusionItemName()
	var counter = subject.curRecipe.getCurIngredientsCounter(subject.bondedIngredients)

	if subject.craftingLabel:
		subject.craftingLabel.updateProgress(fusionName, curNum, outOf,
			counter)
	else:
		subject.craftingLabel = ObjectPool.instantiate(subject.craftingLabelScene)

		subject.craftingLabel.connect("returned_to_pool", Callable(subject, "onCraftingLabelReturned"), subject.CONNECT_ONE_SHOT)
		Game.labelsNode.add_child(subject.craftingLabel)
		subject.craftingLabel.showProgress(fusionName, curNum, outOf,
			counter)

	var topLeftLimit = Vector2(30, 25)
	var itemTopY = subject.getTopLeftGlobal().y - subject.global_position.y
	var counterOffset = counter.size() * 40
	var labelTopLeft = subject.global_position + Vector2(0, itemTopY - counterOffset + 20) + subject.craftingLabel.label.position
	labelTopLeft.x = max(labelTopLeft.x, topLeftLimit.x)
	labelTopLeft.y = max(labelTopLeft.y, topLeftLimit.y)
	subject.craftingLabel.global_position = labelTopLeft - subject.craftingLabel.label.position

	if curNum == outOf:
		Game.onCraftingReady(subject)
		if Util.time >= subject.craftingAniReadyTime:
			subject.craftingAniReadyTime = Util.time + 0.3
			var ani
			var pitch = Util.rng.randf_range(0.97, 1.03)
			if subject.curRecipe.isCatalystRecipe():
				ani = ObjectPool.instantiate(subject.catalystReadyAnimation)
				pitch += 0.1
			else:
				ani = ObjectPool.instantiate(subject.craftingReadyAnimation)
				pitch -= 0.05

			Game.UINode.add_child(ani)
			ani.global_position = subject.global_position
			var scaling = 0.2 + (0.4 * sqrt(subject.getNumOccupiedCells()))
			ani.scale = Vector2(scaling, scaling)
			ani.get_node("AnimationPlayer").play("Shockwave")
			Sound.playSound(subject.craftingReadySound, 3, pitch)

static func createBondVisual(subject: Receiver, bondNeighbor):
	var visual
	if subject.curRecipe == null:
		visual = ObjectPool.instantiate(subject.craftingBondScene)
	elif subject.curRecipe.isNeighborCatalyst(bondNeighbor):
		visual = ObjectPool.instantiate(subject.catalystBondScene)
	else:
		visual = ObjectPool.instantiate(subject.craftingBondScene)

	if subject.isGem() and subject.socket:
		subject.socket.getItem().get_parent().add_child(visual)
	else:
		subject.get_parent().add_child(visual)

	visual.create(subject, bondNeighbor)
	subject.bondVisuals.push_back(visual)

static func fuse(subject: Receiver):

	var catalystBonds: Array
	var nonCatalystBonds: Array
	if subject.curRecipe != null:
		catalystBonds = subject.curRecipe.getCatalystBonds(subject.bondedIngredients)
		nonCatalystBonds = subject.curRecipe.getNonCatalystBonds(subject.bondedIngredients)
	else:
		nonCatalystBonds = subject.bondedIngredients

	for visual in subject.bondVisuals:
		visual.breakBond()
	subject.bondVisuals.clear()

	Sound.playSound(subject.fuseSound1, 4)

	var fusedRarity: int
	if subject.curRecipe != null:
		fusedRarity = subject.curRecipe.fusedItem.rarity
		Util.callDelayed(subject, "createCraftedShockwave", 0.8, [subject.curRecipe.fusedItem])
	else:
		fusedRarity = subject.getRarity()

	subject.fuseTween = Util.refreshTween(subject.fuseTween)
	subject.fuseTween.set_parallel(true)
	var mat = subject.fuseMaterial.duplicate()
	var catalystMat = null

	if not catalystBonds.is_empty():
		catalystMat = subject.fuseMaterial.duplicate()

	for neighbor in subject.bondedIngredients:
		neighbor.fusing = true
		neighbor.onFusingAsIngredient()

	for neighbor in nonCatalystBonds:
		neighbor.sprite.set_material(mat)

	for neighbor in catalystBonds:
		neighbor.sprite.set_material(catalystMat)

	var GROW_DUR = 0.17
	var SHRINK_DUR = 0.25
	var GROW_FACTOR = 1.1
	var timeUsed = 0.0
	while timeUsed <= subject.FUSE_DUR:
		subject.fuseTween.tween_property(subject.sprite, subject.getScaleProp(),
			subject.spriteScale * GROW_FACTOR, GROW_DUR).from(subject.spriteScale).set_delay(timeUsed)
		subject.fuseTween.tween_property(subject.sprite, subject.getScaleProp(),
			subject.spriteScale, SHRINK_DUR).from(subject.spriteScale * GROW_FACTOR).set_delay(timeUsed + GROW_DUR)
		timeUsed += GROW_DUR + SHRINK_DUR

		GROW_FACTOR += 0.2

	var maxScale = Vector2(1.2, 1.2)
	var scaleDur = 0.7

	for neighbor in nonCatalystBonds:
		neighbor.z_index += 1
		subject.fuseTween.tween_property(neighbor, "global_position", subject.global_position, subject.FUSE_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		subject.fuseTween.tween_property(neighbor, "scale", maxScale, scaleDur)
		subject.fuseTween.tween_property(neighbor, "scale", Vector2(0.7, 0.7), subject.FUSE_DUR - scaleDur).from(maxScale).set_delay(scaleDur)

	for neighbor in catalystBonds:
		subject.fuseTween.tween_callback(Callable(neighbor, "onFusingAsCatalystFinished")).set_delay(subject.FUSE_DUR)

	subject.sprite.set_material(mat)

	subject.fuseTween.tween_property(mat, "shader_parameter/flashState", 1.0, subject.FUSE_DUR).from(0.0)
	var flashColor = subject.rarityColors[fusedRarity].lightened(0.4) * 4
	subject.fuseTween.tween_property(mat, "shader_parameter/flashColor", flashColor, subject.FUSE_DUR).from(Color(1, 1, 1, 1))

	if catalystMat != null:
		var undoFlashDur = 0.1
		subject.fuseTween.tween_property(catalystMat, "shader_parameter/flashState", 1.0, subject.FUSE_DUR - undoFlashDur).from(0.0)
		subject.fuseTween.tween_property(catalystMat, "shader_parameter/flashState", 0.0, undoFlashDur).from(1.0).set_delay(subject.FUSE_DUR - undoFlashDur)
		subject.fuseTween.tween_property(catalystMat, "shader_parameter/flashColor", flashColor, subject.FUSE_DUR).from(Color(1, 1, 1, 1))

	var particleNode = subject.get_parent()

	var particleColor = subject.rarityColors[fusedRarity].lightened(0.3) * 2.5
	subject.fuseParticles1 = ObjectPool.instantiate(subject.fuseParticlesScene1)
	particleNode.add_child(subject.fuseParticles1)
	subject.fuseParticles1.global_position = subject.global_position
	subject.fuseParticles1.self_modulate = particleColor
	subject.fuseParticles1.modulate.a = 1
	subject.fuseParticles1.scale = Vector2.ONE
	subject.fuseParticles1.speed_scale = 1.0
	subject.fuseParticles1.restart()

	subject.fuseTween.tween_property(subject.fuseParticles1, "speed_scale", 2.2, subject.FUSE_DUR).from(1.0)
	subject.fuseTween.tween_property(subject.fuseParticles1, "scale", Vector2(0.3, 0.3), subject.FUSE_DUR - 0.2).set_delay(0.2)
	subject.fuseTween.tween_property(subject.fuseParticles1, "modulate:a", 0.0, 0.2).set_delay(subject.FUSE_DUR - 0.2)

	subject.fuseParticles2 = ObjectPool.instantiate(subject.fuseParticlesScene2)
	particleNode.add_child(subject.fuseParticles2)

	if subject.curRecipe == null:
		subject.fuseParticles2.amount = 45
	else:
		subject.fuseParticles2.amount = 35 + 5 * Game.itemLibrary.getInstance(subject.curRecipe.fusedItem).getNumOccupiedCells()

	subject.fuseParticles2.global_position = subject.global_position
	subject.fuseParticles2.self_modulate = particleColor

	subject.fusingBonds = subject.bondedIngredients.duplicate()

	if subject.placed:
		for neighbor in nonCatalystBonds:
			if neighbor.placed:
				subject.inventory.clearItemCells(neighbor)

	if subject.isGem():
		subject.z_index += 3

	subject.bondedIngredients.clear()

static func createCraftedShockwave(subject: Receiver, fusedItem):
	var ani = ObjectPool.instantiate(subject.craftedAnimation)
	Game.UINode.add_child(ani)
	ani.global_position = subject.global_position
	var scaling = 0.5 + (0.5 * sqrt(Game.itemLibrary.getInstance(fusedItem).getNumOccupiedCells()))
	ani.scale = Vector2(scaling, scaling)
	ani.get_node("Sprite2D/Light3D").self_modulate = subject.rarityColors[fusedItem.rarity].lightened(0.4)
	ani.get_node("AnimationPlayer").play("Shockwave")

static func getNextFreeLabelPosition(subject: Receiver) -> Vector2:
	var pos = subject.global_position
	for i in subject.buffLabelPositionTimestamps.size():
		var time = subject.buffLabelPositionTimestamps[i]
		if Util.time >= time:
			subject.buffLabelPositionTimestamps[i] = Util.time + 0.5
			pos += subject.labelOffsets[i]
			pos += Util.randInBox(10, 10)
			return pos
	return pos + Util.randInBox(30, 30)

static func findBondsWithAffectedItems(subject: Receiver):
	if subject.ownerType != subject.Owner.PlayerInventory:
		return

	if subject.locked or not subject.placed:
		for bonded in subject.bondedIngredients:
			bonded.removeBondedBaseItem()
		subject.removeAllIngredients()
		return

	if subject.isBoundAsIngredient() or subject.fusing:
		return

	for item in subject.getAffectedItems():
		if item.canStartNewRecipe():

			subject.bondedIngredients.push_back(item)
			subject.createBondVisual(item)
			subject.updateBondVisuals()
			item.addToBaseItem(subject)
