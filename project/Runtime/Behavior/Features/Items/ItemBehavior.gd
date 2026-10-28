extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func _enter_tree(subject: Receiver) -> void:
	# Static recipe-book items need their descriptor before derived @onready
	# expressions run; Godot 4 initializes those before the parent _ready.
	if not subject.pooled and subject.descriptor == null and ItemBook.items.has(str(subject.name)):
		subject.descriptor = ItemBook.getDescriptor(str(subject.name))
		subject.ownerType = subject.Owner.RecipeBook

static func initItemLibrary(subject: Receiver):
	subject.disablePicking()
	subject.disableFocus()
	for shadow in subject.shadows:
		shadow.hide()
	subject.collisionShape.disabled = true
	subject.set_collision_layer(0)
	subject.set_collision_mask(0)
	subject.set_process(false)
	subject.call_deferred("enableFocus")

	subject.set_process_input(true)

static func initTitle(subject: Receiver):
	subject.disablePicking()
	subject.disableTooltip()
	subject.makeRigidBody()
	subject.disableFocus()
	for shadow in subject.shadows:
		shadow.show()
	subject.collisionShape.disabled = false
	subject.clickArea.hide()
	subject.set_process(true)
	subject.set_process_input(false)

static func initTooltip(subject: Receiver):
	subject.disableTooltip()
	subject.disablePicking()
	subject.disableFocus()
	for shadow in subject.shadows:
		shadow.hide()
	subject.collisionShape.disabled = true
	subject.clickArea.hide()
	subject.set_collision_layer(0)
	subject.set_collision_mask(0)
	subject.set_process(false)
	subject.set_process_input(false)

static func initBuildViewer(subject: Receiver):
	subject.enableTooltip()
	subject.enableFocus()
	subject.clickArea.show()
	subject.disablePicking()
	subject.collisionShape.disabled = true
	subject.set_collision_layer(0)
	subject.set_collision_mask(0)
	for shadow in subject.shadows:
		shadow.show()

	subject.set_process_input(false)

static func initBuildViewerIcon(subject: Receiver):
	subject.enableTooltip()
	subject.disablePicking()
	subject.enableFocus()
	for shadow in subject.shadows:
		shadow.hide()
	subject.collisionShape.disabled = true
	subject.clickArea.show()
	subject.set_collision_layer(0)
	subject.set_collision_mask(0)
	subject.set_process_input(false)

static func getTranslatedName(subject: Receiver, removeLinebreaks) -> String:
	if subject.pve_is_view(): return Expedition.t(str(subject.pve_definition().get("name_key", "")))
	if removeLinebreaks:
		return subject.descriptor.getTranslatedName().replace("\n", "")
	else:
		return subject.descriptor.getTranslatedName()

static func isWeapon(subject: Receiver) -> bool:
	if subject.pve_is_view(): return "weapon" in str(subject.pve_definition().get("tags", "")).split("|")
	return subject.descriptor.isWeapon()

static func getGlobalPointsForCells(subject: Receiver, cells):
	var points = []
	for cell in cells:
		points.push_back(subject.collisionMap.to_global(LegacyGrid.cell_origin(subject.collisionMap, cell))
			+ subject.halfCellSize.rotated(subject.global_rotation))

	return points

static func getGlobalPointsForCells_noRotate(subject: Receiver, cells):
	var points = []
	for cell in cells:
		points.push_back(subject.collisionMap.global_position
			+ (LegacyGrid.cell_origin(subject.collisionMap, cell))
			+ subject.halfCellSize)

	return points

static func getNumOccupiedCells(subject: Receiver):
	if subject.pve_is_view(): return Expedition.flow.placement.local_cells(Expedition.bridge.item_entry(subject)).size()
	return subject.collisionCells.size()

static func getNumAffectedCells(subject: Receiver, color) -> int:
	if color in subject.affectedCellsCache:
		return subject.affectedCellsCache[color].size()
	else:
		return subject.getAffectedCells_tilemap(color).size() + subject.getAffectedCells_noRotate(color).size()

static func getAffectedItems(subject: Receiver, color) -> Array:
	if not subject.cachedAffectedItems.is_empty():

		return subject.cachedAffectedItems[color]

	var items = []
	for item in subject.getItemsInAffectedCells_cached(color):
		if subject.canAffect_color(item, color):
			items.push_back(item)
	return items

static func isItemAffected(subject: Receiver, item, color) -> bool:
	if item.isBag() or not subject.canAffect_color(item, color):
		return false

	var affectedTiles = subject.getAffectedCellsInInventory_cached(color)

	for cell in item.occupiedCells:
		if cell in affectedTiles:
			return true
	return false

static func getTopLeftCell(subject: Receiver) -> Vector2:
	var topLeft = Vector2(INF, INF)
	for cell in subject.occupiedCells:
		topLeft.x = min(cell.x, topLeft.x)
		topLeft.y = min(cell.y, topLeft.y)
	return topLeft

static func getBottomCenter(subject: Receiver) -> Vector2:
	if subject.pve_is_view() and subject.ownerType == subject.Owner.Shop and not subject.dragged and subject.has_meta("pve_visual_bounds"):
		var rectangle: Rect2 = subject.get_meta("pve_visual_bounds")
		return Vector2(rectangle.get_center().x, rectangle.end.y)
	if subject.pve_is_view() and subject.has_meta("pve_anchor"): return Vector2(subject.get_meta("pve_anchor")) + Vector2(subject.get_meta("pve_size")) * Vector2(0.5, 1.0)
	return subject.get_node("BottomCenter").position

static func cleanCachedAffectedItems(subject: Receiver):
	subject.affectedCellsCache.clear()

	for color in subject.Affected.values():
		subject.currentAffectedItems[color].clear()

	Util.eassert(subject.cachedAffectedItems.is_empty())

static func onItemRemoved(subject: Receiver, item):
	for color in subject.Affected.values():
		subject.currentAffectedItems[color].erase(item)
		if subject.canAffectDraggedItem(item, color):

			subject.onAffectedItemRemoved(item, color)

static func canAffectDraggedItem(subject: Receiver, item, color):
	if subject.canAffect_color(item, color):

		var affectedCells = subject.getAffectedCellsInInventory_cached(color)

		for cell in affectedCells:
			if item.dragged:
				if subject.inventory.isHovered(cell):
					return true
			else:
				if cell in item.occupiedCells:
					return true
	return false

static func pushToStorage(subject: Receiver, targetPos):
	if subject.pve_is_view():
		Expedition.bridge.store_item(subject)
		return
	if subject.isBag():
		subject.z_index = 41
	else:
		subject.z_index = 42
	subject.addToStorageBox(true, true, true, targetPos, 1.0, true)

static func onStorageLeft(subject: Receiver):
	subject.makeNonRigidBody()
	Game.STORAGEBOX.removeItem(subject)
	Util.tryDisconnect(Game.shopSceneNode, "roll_sale", subject, "onSaleRoll_storage")
	Util.tryDisconnect(Game.shopSceneNode, "gate_item_roll", subject, "onGateItemRoll_storage")

static func updateShadow(subject: Receiver):

	for i in subject.shadows.size():
		var shadow = subject.shadows[i]
		var node = subject.spritesWithShadows[i]
		shadow.global_position = node.global_position + subject.shadowOffset
		shadow.global_rotation = node.global_rotation
		shadow.global_scale = node.global_scale
		shadow.offset = node.offset

static func rotateRight(subject: Receiver):
	subject.faceDirection += 1
	subject.faceDirection = subject.faceDirection % subject.FaceDirection.size()
	subject.setFaceDirection(subject.faceDirection)
	Sound.playSound(subject.rotateSound, - 6, Util.rng.randf_range(0.8, 1.3))
	subject.spawnRotationSparks(true)
	Game.onItemRotated()

static func rotateLeft(subject: Receiver):
	subject.faceDirection -= 1
	subject.faceDirection += subject.FaceDirection.size()
	subject.faceDirection = subject.faceDirection % subject.FaceDirection.size()
	subject.setFaceDirection(subject.faceDirection)
	Sound.playSound(subject.rotateSound, - 6)
	subject.spawnRotationSparks(false)
	Game.onItemRotated()

static func spawnRotationSparks(subject: Receiver, rotateRight):
	var rotationSparks = subject.createParticles(subject.rotationSparksScene)
	rotationSparks.modulate = Game.rarityColors[subject.getRarity()].lightened(0.2)

	if rotateRight:
		rotationSparks.scale.x = - abs(rotationSparks.scale.x)
	else:
		rotationSparks.scale.x = abs(rotationSparks.scale.x)

static func canGainFocus(subject: Receiver):
	return (subject.is_inside_tree() and is_instance_valid(Game.combatLog) and not Game.SELECTING and
		( not Game.draggedItem or Game.draggedItem == subject) and
		subject.focusEnabled and
		not subject.focus)

static func gainFocus(subject: Receiver):
	if not subject.canGainFocus(): return

	if (subject.ownerType == subject.Owner.PlayerInventory or
		subject.ownerType == subject.Owner.Socket or
		subject.ownerType == subject.Owner.Opponent):
		Game.combatLog.highlightItem(subject, false)

	subject.focus = true
	subject.respondToHover()

static func canShowSubBuildIntoRecipesTooltip(subject: Receiver):
	var ownerType_ = Game.lockedTooltipItem.getEffectiveOwnerType()
	return (ownerType_ == subject.Owner.Shop or
			ownerType_ == subject.Owner.PlayerInventory or
			ownerType_ == subject.Owner.PlayerStorageBox)

static func mouseEntered(subject: Receiver):
	Game.onItemUnderMouse(subject)
	if Game.itemsUnderMouse.size() > 10:
		Util.eprint("items under mouse: ", Game.itemsUnderMouse)

	subject.hover()

static func hoverEnd(subject: Receiver):
	if not subject.tooltipEnabled: return
	if subject.spotlight: return
	if subject == Game.lockedTooltipItem: return

	subject.hovered_state = false
	subject.loseFocus()

	Game.itemHoverEnd(subject)

	subject.emit_signal("unhovered")

static func moveTo(subject: Receiver, fromPos, newPos, duration, transitionType):
	subject.killMovebackTween()
	subject.global_position = newPos
	subject.sprite.global_position = fromPos
	subject.movebackTween = subject.create_tween()
	subject.movebackTween.tween_method(Callable(subject, "setSpriteGlobalPos"), fromPos, newPos, duration).set_ease(Tween.EASE_OUT).set_trans(transitionType)

static func pushGemsToStorage(subject: Receiver):
	for socket in subject.sockets:
		var gem = socket.getGem()
		if gem != null:
			if not gem.fusing:
				gem.pushToStorage(Game.STORAGEBOX.center)

static func getGemData(subject: Receiver):
	var gemData = []
	for gem in subject.getGems():
		if gem != null:
			gemData.push_back([
				ItemBook.getGemIndex(gem),
				gem.getFaceDirection(),
				gem.isLocked()
				])
		else:
			gemData.push_back(null)
	return gemData

static func setGem(subject: Receiver, socketId: int, gem):
	if socketId >= subject.sockets.size():
		print("ohnonononononno")
	else:
		gem.ownerType = subject.Owner.Socket
		subject.sockets[socketId].add_child(gem)
		gem.addToSocket(subject.sockets[socketId])
		gem.global_position = subject.sockets[socketId].global_position
		gem.rotation = subject.rotation

static func isPickingPossible(subject: Receiver) -> bool:
	return (subject.pickingEnabled and
			not subject.dragged and
			not Game.draggedItem and
			not Util.isTweenRunning(subject.movebackTween) and
			not subject.draggingParent and
			not InputBlocker.isActive() and
			Game.lockedTooltipItem == null and
			not Game.replacementPending)

static func preCombatStart(subject: Receiver):
	for gem in subject.getGemsNoNull():
		gem.preCombatStart()

	if subject.hasCooldown():
		subject.iterationCooldown = subject.adjustCooldown()
		subject.triggerTime = subject.iterationCooldown
		subject.activateCooldown()
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown)

	subject.onPreCombatStart()

static func giveGold(subject: Receiver, amount: int):
	Game.gainGold(amount)
	var coinParticles = Game.shootGold(subject.global_position, Game.PLAYER.getGoldPos(), subject.getP1())
	coinParticles.z_index = Util.getGlobalZ(Game.UINode)
	subject.activate(null, false)
	Game.saveRunState()

static func canAffect_color(subject: Receiver, item, color):
	if color == subject.Affected.Primary:
		return subject.canAffect(item)
	elif color == subject.Affected.Secondary:
		return subject.canAffect_secondary(item)
	elif color == subject.Affected.Tertiary:
		return subject.canAffect_tertiary(item)
	else:
		return subject.canAffect_lightning(item)

static func addDynamicType(subject: Receiver, type: int, byItem: Item):
	if not type in subject.descriptor.types:
		Util.dictAppend(subject.dynamicTypes, type, byItem.get_instance_id())

		if subject.dynamicTypes[type].size() == 1:
			if subject.placed:
				subject.inventory.onItemTypeChanged(subject)
			if type in subject.typeTransformationParticles:
				ObjectPool.particleOneShot(subject.typeTransformationParticles[type], subject)

static func removeDynamicType(subject: Receiver, type: int, byItem: Item):
	if subject.hasDynamicType(type, byItem):
		Util.dictErase(subject.dynamicTypes, type, byItem.get_instance_id())

		if not type in subject.dynamicTypes:
			if subject.placed:
				subject.inventory.onItemTypeChanged(subject)

static func getDamageRange(subject: Receiver) -> String:
	if subject.getMinDamage() == subject.getMaxDamage():
		return str(subject.getMinDamage())
	else:
		return str(subject.getMinDamage()) + "-" + str(subject.getMaxDamage())

static func getBaseCooldownIndex(subject: Receiver, index: int) -> float:
	if subject.pve_is_view(): return subject.pve_stat("base_cooldown") if index == 0 else 0.0
	if index == 0:
		return subject.descriptor.cd
	else:
		return subject.descriptor.extraCds[index - 1]

static func getAccuracy(subject: Receiver) -> float:
	if subject.pve_is_view(): return 100.0
	var override = subject.statDisplayOverrides[subject.Stat.Accuracy]
	if override: return override

	var acc = subject.getBaseAccuracy()
	acc += subject.bonusAccuracy
	if subject.hasCharacter():
		acc += subject.character().getBuffAccuracyMod()
	return acc

static func getCombatDisplayAccuracy(subject: Receiver) -> String:
	var acc = subject.getAccuracy()
	if acc > 100:
		return ">100"
	elif acc < 0:
		return "<0"
	else:
		return str(acc)

static func applyBonusChance(subject: Receiver, toChance, index) -> float:
	if index == 1:
		return (toChance + subject.bonusChancePercent_additive1) * ((100 + subject.bonusChancePercent_mult) / 100.0)
	else:
		return (toChance + subject.bonusChancePercent_additive2) * ((100 + subject.bonusChancePercent_mult) / 100.0)

static func getParamModified(subject: Receiver, paramName: String, baseVal) -> float:
	var baseParam = subject.descriptor.paramBases[paramName]
	return (baseVal + subject.paramAdd.get(baseParam, 0)) * subject.paramMult.get(baseParam, 1.0)

static func getPrice(subject: Receiver):
	if subject.pve_is_view():
		return int(Expedition.flow.placement.definition(str(subject.get_meta("pve_definition_id"))).get("base_price", 0))
	return subject.descriptor.getPrice()

static func getCritChancePercent(subject: Receiver) -> float:
	if subject.pve_is_view(): return subject.pve_stat("crit_chance") * 100.0
	var override = subject.statDisplayOverrides[subject.Stat.CritChance]
	if override != null: return override

	return clamp(subject.critChancePercent, 0, 100)

static func addBonusChance_additive(subject: Receiver, amount1, amount2):
	subject.bonusChancePercent_additive1 += amount1

	if amount2 == null:
		subject.bonusChancePercent_additive2 += amount1
	else:
		subject.bonusChancePercent_additive2 += amount2

	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Chance)

	if amount2 != 0:
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Chance2)

static func reduceBonusDamage(subject: Receiver, damage, showLabel: bool, removable: bool):
	subject.bonusMinDam -= damage
	subject.bonusMaxDam -= damage
	if removable:
		subject.removableDam -= damage
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.MinDamage)
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.MaxDamage)

	if showLabel:
		subject.spawnLabel(Game.EventType.DamageBuff, - damage)

static func purgeDamage(subject: Receiver, damage):
	var purgable = min(damage, subject.removableDam)
	if purgable > 0:
		subject.removableDam -= purgable
		subject.bonusMinDam -= purgable
		subject.bonusMaxDam -= purgable
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.MinDamage)
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.MaxDamage)

		subject.spawnLabel(Game.EventType.DamageBuff, - purgable)

static func dealDamage(subject: Receiver, triggerEvent):
	subject.damageSource.updateItem(subject)
	var damageRes = subject.character().dealDamage(subject.damageSource, triggerEvent)
	EventBus.emitSignal(subject, "attacked", [damageRes])
	return damageRes

static func giveMaxHealth(subject: Receiver, amount, triggerEvent):
	amount = subject.character().applyTemporaryMaxHealthGain(amount)
	if amount > 0:
		subject.addMetric(Game.ItemMetrics.MaxHealth, amount, null, true)
		subject.character().changeMaxHealthTemporary(amount, subject, triggerEvent)
		subject.spawnLabel(Game.EventType.TemporaryMaxHealth, amount)

static func disappear(subject: Receiver):
	subject.shadowTween = Util.refreshTween(subject.shadowTween)
	subject.shadowTween.tween_property(subject, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN_OUT)
	subject.shadowTween.tween_callback(Callable(subject, "discard"))

static func appearInLibrary(subject: Receiver):
	subject.show()
	subject.scale = Vector2.ZERO
	subject.animation.stop()
	if subject.isBag():
		subject.animation.play("AppearInLibrarySmall")
	else:
		subject.animation.play("AppearInLibrary")

static func makeRigidBody(subject: Receiver):
	subject.mode = 0
	if subject.ownerType == subject.Owner.Title:
		subject.set_collision_layer_value(3, true)
		subject.set_collision_mask_value(3, true)
	else:
		subject.set_collision_layer_value(1, true)
		subject.set_collision_mask_value(1, true)

static func trigger(subject: Receiver):
	if subject.pve_is_view(): return
	subject.iterationCooldown = subject.adjustCooldown()
	subject.triggerTime += subject.iterationCooldown

	subject.doCooldownEffect()

	if subject.doubleActivationChance > 0 and Util.flip(subject.doubleActivationChance):
		subject.doCooldownEffect()

static func updateBaseCooldown(subject: Receiver):
	var cdProgress = subject.triggerTime / subject.iterationCooldown
	subject.iterationCooldown = subject.adjustCooldown()
	subject.triggerTime = cdProgress * subject.iterationCooldown
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown)
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.BaseCooldown)

static func _physics_process(subject: Receiver, delta: float):
	if subject.pve_is_view(): return
	if not subject.character().isStunned():
		subject.triggerTime -= delta * subject.getSpeed()
		subject.showCooldown(1.0 - (subject.triggerTime / subject.iterationCooldown))
		if subject.triggerTime <= 0:
			subject.trigger()

static func getCooldownEncoded(subject: Receiver):
	if subject.iterationCooldown == 0:
		return - 1
	var relProgress = 1.0 - subject.triggerTime / subject.iterationCooldown
	var progressPerSecond: float
	if subject.is_physics_processing():
		progressPerSecond = subject.getSpeed() / subject.iterationCooldown
	else:
		progressPerSecond = 0
	var value = int(relProgress * subject.cdEncodingFactor) << 32
	value += int(progressPerSecond * subject.cdEncodingFactor)
	return value

static func reconstructCooldown(subject: Receiver, encodedCd, timeSinceEntry):
	if encodedCd == - 1:
		subject.showCooldown(0)
	else:
		var progressPerSecond: float = (encodedCd % int(pow(2, 32))) / subject.cdEncodingFactor
		var relProgress = (encodedCd >> 32) / subject.cdEncodingFactor
		var curProgress = relProgress + progressPerSecond * timeSinceEntry
		subject.showCooldown(curProgress)

static func advanceCooldownPercent(subject: Receiver, amount):
	if not subject.isCooldownActive(): return

	var reduction = amount / 100.0 * subject.iterationCooldown
	subject.triggerTime -= reduction

	while subject.triggerTime <= 0:
		subject.trigger()
		if not subject.isCooldownActive(): return

	Util.spawnLabelOnItem(Game.EventType.CooldownAdvance, subject, reduction)
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown)

static func advanceCooldownSeconds(subject: Receiver, amount):
	if not subject.isCooldownActive(): return

	subject.triggerTime -= amount * subject.getSpeed()

	while subject.triggerTime <= 0:
		subject.trigger()
		if not subject.isCooldownActive(): return

	Util.spawnLabelOnItem(Game.EventType.CooldownAdvance, subject, amount)
	Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown)

static func playActivationAnimation_Scale(subject: Receiver, maxScale: float):
	subject.shadowTween = Util.refreshTween(subject.shadowTween)
	subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	subject.shadowTween.tween_property(subject.sprite, "scale", subject.spriteScale * maxScale, 0.2).set_ease(Tween.EASE_IN_OUT)
	subject.shadowTween.tween_property(subject.sprite, "scale", subject.spriteScale, 0.3).set_ease(Tween.EASE_IN_OUT)

static func spawnLabel(subject: Receiver, type, amount):
	var setting = Settings.getVal(Settings.Setting.damage_numbers)
	if setting == Settings.DMG_NR_ALL or setting == Settings.DMG_NR_ITEMS:
		Util.spawnLabelOnItem(type, subject, amount)

static func stealStack(subject: Receiver, type: int, amount, triggerEvent):
	var removeEvent = subject.opponent().loseStacks(type, amount, subject, triggerEvent)
	var giveEvent = subject.giveStacks(subject.character(), type, amount, removeEvent)
	return giveEvent

static func cleansePoison(subject: Receiver, amount: int, triggerEvent) -> int:
	var curPoison = subject.character().getPoison()
	if curPoison == 0:
		return 0

	amount = min(curPoison, amount)
	subject.character().losePoison(amount, subject, triggerEvent)
	return amount

static func cleanseBlind(subject: Receiver, amount: int, triggerEvent) -> int:
	var curBlind = subject.character().getBlind()
	if curBlind == 0:
		return 0

	amount = min(curBlind, amount)
	subject.character().loseBlind(amount, subject, triggerEvent)
	return amount

static func cleanseCold(subject: Receiver, amount: int, triggerEvent) -> int:
	var curCold = subject.character().getCold()
	if curCold == 0:
		return 0

	amount = min(curCold, amount)
	subject.character().loseCold(amount, subject, triggerEvent)
	return amount

static func healthToBlock(subject: Receiver, health: float, block, triggerEvent):
	var clampedHealth = min(health, subject.character().getCurrentHealth() - 1)
	if clampedHealth > 0:
		subject.character().loseHealth(clampedHealth, subject, triggerEvent)

		block = ceil((clampedHealth / health) * block)
		subject.giveBlock(block, true, triggerEvent)

static func getModifiedEffectDamage(subject: Receiver, baseDamage):
	var modifiedDamage = baseDamage
	modifiedDamage *= (1.0 + subject.character().typedDamageFactors[Game.stealLifeDamageSource.Type.Effect])
	modifiedDamage *= subject.bonusDamageFactor
	return modifiedDamage

static func stealLife(subject: Receiver, damage, lifestealFactor: float, triggerEvent):
	Game.stealLifeDamageSource.updateEffect(subject, damage)
	var damageRes = subject.opponent().takeDamage(Game.stealLifeDamageSource, triggerEvent)
	subject.heal(damageRes.damage * lifestealFactor, damageRes.event)
	return damageRes

static func scaleToFit(subject: Receiver, maxSize: Vector2, maxScale: float):
	var size = subject.getTextureSize()
	var fill = size / maxSize
	subject.scale /= max(1.0 / maxScale, max(fill.x, fill.y))

static func scaleToFit_local(subject: Receiver, maxSize: Vector2, maxScale: float):
	var size = subject.getTextureSize_local()
	var fill = size / maxSize
	subject.scale /= max(1.0 / maxScale, max(fill.x, fill.y))

static func rotateProgress(subject: Receiver, progress: float):

	match subject.faceDirection:
		subject.FaceDirection.UP:
			progress = 1.0 - progress
		subject.FaceDirection.RIGHT:
			progress = 1.0 - progress
		subject.FaceDirection.LEFT:
			progress = - progress
		subject.FaceDirection.DOWN:
			progress = - progress
	return progress

static func showCooldown(subject: Receiver, progress: float):

	subject.nonRotatedProgress = progress
	if progress != 0:
		if not subject.sprite.material:
			subject.updateShaderRotation()
		progress = subject.rotateProgress(progress * 1.0 + 0.05)
		subject.sprite.material.set_shader_parameter("progress", progress)
	else:
		subject.clearSpriteMaterial()

static func pickRandomStacksToGive(subject: Receiver, stackTypes, numStacks):
	var pickedStacks = Dictionary()
	for i in numStacks:
		var stackType = Util.pickRandomElement(stackTypes)
		Util.dictAdd(pickedStacks, stackType, 1)

	return pickedStacks

static func giveRandomBuffs(subject: Receiver, numBuffs: int, triggerEvent, availableBuffs, target):

	var pickedBuffs = subject.pickRandomStacksToGive(availableBuffs, numBuffs)
	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in pickedBuffs:
		subject.giveStacks(target, buff, pickedBuffs[buff], triggerEvent)
	EventBus.flushLoggingQueue()

static func inflictRandomDebuffs(subject: Receiver, numDebuffs, triggerEvent, availableDebuffs):
	var pickedDebuffs = subject.pickRandomStacksToGive(availableDebuffs, numDebuffs)

	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for debuff in pickedDebuffs:
		subject.giveStacks(subject.opponent(), debuff, pickedDebuffs[debuff], triggerEvent)

	EventBus.flushLoggingQueue()

static func removeRandomBuffs(subject: Receiver, numBuffs, triggerEvent):
	var removedStacks = subject.pickRandomStacks(Game.getBuffs(), numBuffs, subject.opponent())
	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in removedStacks:
		subject.opponent().loseStacks(buff, removedStacks[buff], subject, triggerEvent)
	EventBus.flushLoggingQueue()

static func cleanseRandomDebuffs(subject: Receiver, numDebuffs, triggerEvent):
	var cleansedDebuffs = subject.pickRandomStacks(Game.getDebuffs(), numDebuffs, subject.character())

	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for debuff in cleansedDebuffs:
		subject.character().loseStacks(debuff, cleansedDebuffs[debuff], subject, triggerEvent)

	EventBus.flushLoggingQueue()

static func giveMostBuffs(subject: Receiver, numBuffs, triggerEvent, availableBuffs):
	var maxBuffs = subject.getMostStacks(subject.character(), availableBuffs)
	var buffToGive = Util.pickRandomElement(maxBuffs)
	subject.giveStacks(subject.character(), buffToGive, numBuffs, triggerEvent)

static func multiplyBuffsLimit(subject: Receiver, bonus: float, limit: int, availableBuffs):

	var buffsToGive = subject.getStackFraction(subject.character(), bonus, limit, availableBuffs)
	if buffsToGive == null: return

	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in buffsToGive:
		subject.giveStacks(subject.character(), buff, buffsToGive[buff])
	EventBus.flushLoggingQueue()

static func removeBuffsFraction(subject: Receiver, fraction: float, limit: int, triggerEvent, availableBuffs):

	var buffsToRemove = subject.getStackFraction(subject.opponent(), fraction, limit, availableBuffs)
	if buffsToRemove == null: return

	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in buffsToRemove:
		subject.opponent().loseStacks(buff, buffsToRemove[buff], subject, triggerEvent)
	EventBus.flushLoggingQueue()

static func stealBuffsFraction(subject: Receiver, fraction: float, limit: int, triggerEvent, availableBuffs):

	var buffsToSteal = subject.getStackFraction(subject.opponent(), fraction, limit, availableBuffs)
	if buffsToSteal == null: return

	EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
	for buff in buffsToSteal:
		subject.stealStack(buff, buffsToSteal[buff], triggerEvent)
	EventBus.flushLoggingQueue()

static func getNeighborItemsAndGems(subject: Receiver):
	var neighbors = subject.inventory.getAdjacentItems(subject)
	neighbors.append_array(subject.getGemsNoNull())
	for neighbor in neighbors:
		var neighborGems = neighbor.getGemsNoNull()
		neighbors.append_array(neighborGems)
	return neighbors

static func getCraftableNeighbors(subject: Receiver):
	var craftableNeighbors = []

	for neighbor in subject.getNeighborItemsAndGems():
		if neighbor.isAvailableForCrafting():
			craftableNeighbors.push_back(neighbor)

	for bag in subject.getTouchedBags():
		if bag.isAvailableForCrafting():
			craftableNeighbors.push_back(bag)

	return craftableNeighbors

static func getBusyNeighbors(subject: Receiver):
	var busyNeighbors = []

	for neighbor in subject.getNeighborItemsAndGems():
		if neighbor.isBusy():
			busyNeighbors.push_back(neighbor)

	for bag in subject.getTouchedBags():
		if bag.isBusy():
			busyNeighbors.push_back(bag)

	return busyNeighbors

static func breakBondVisual(subject: Receiver, toItem):
	var bondIndex = subject.bondedIngredients.find(toItem)
	if bondIndex != - 1:
		subject.bondVisuals[bondIndex].breakBond()
		subject.bondVisuals.erase(subject.bondVisuals[bondIndex])

static func removeBondedIngredient(subject: Receiver, item):

	subject.breakBondVisual(item)
	subject.bondedIngredients.erase(item)

	if subject.fusing:
		return

	subject.showProgressLabel()

	if subject.bondedIngredients.is_empty():
		subject.curRecipe = null

	else:
		subject.updateBondVisuals()

static func addBondedIngredient(subject: Receiver, forRecipe, neighbor):
	if subject.curRecipe:

		pass
	else:
		subject.curRecipe = forRecipe

	subject.bondedIngredients.push_back(neighbor)
	subject.createBondVisual(neighbor)
	subject.updateBondVisuals()
	subject.playBondAnimation()

	if neighbor.placedByPlayer or subject.placedByPlayer:
		subject.showProgressLabel()

static func canBeLocked(subject: Receiver) -> bool:
	if (subject.ownerType == subject.Owner.PlayerInventory or
		subject.ownerType == subject.Owner.PlayerStorageBox or
		(subject.ownerType == subject.Owner.Socket and subject.character() == Game.PLAYER)):

		if Game.state == Game.State.Combat:
			return subject.focus
		else:
			return subject.canBePicked()

	return false

static func unlockCombining(subject: Receiver, playAni: bool):

	subject.locked = false
	if playAni:
		subject.lockAnimation.play("Unlock")
	if subject.canCombine():
		CraftingManager.itemAdded(subject)
	subject.previewFusions()
	Sound.playSound(subject.unlockSound, 0, Util.rng.randf_range(0.95, 1.05))

static func lockCombining(subject: Receiver, showLabel):

	subject.locked = true
	subject.lockAnimation.play("Lock")
	if subject.canCombine():
		CraftingManager.itemRemoved(subject)
	subject.previewFusions()
	if showLabel:
		subject.showLockLabel()
		Sound.playSound(subject.lockSound, 0, Util.rng.randf_range(0.95, 1.05))

static func canPreviewFusions(subject: Receiver):
	return ((subject.ownerType == subject.Owner.Shop or
		subject.ownerType == subject.Owner.PlayerInventory or
		subject.ownerType == subject.Owner.PlayerStorageBox) and
		Game.state == Game.State.Shop)

static func previewFusionToItem(subject: Receiver, hoveredIngredient):
	for recipe in subject.getRecipes(false):
		for ingredient in recipe.ingredients:
			if (recipe.fitsIngredient(hoveredIngredient, ingredient) and
				not hoveredIngredient in subject.bondedIngredients and
				not subject in hoveredIngredient.bondedIngredients):
				CraftingManager.call_deferred("createFusionPreview",
					subject, hoveredIngredient, hoveredIngredient.getGridStorageProxy())
				break

static func updateBondVisuals(subject: Receiver):
	for visual in subject.bondVisuals:
		if subject.curRecipe == null or subject.curRecipe.getProgress(subject.bondedIngredients) == 1:
			visual.setStrong()
		else:
			visual.setWeak()

static func onFusingFinished(subject: Receiver, validBonds):
	for item in validBonds:
		item.pushGemsToStorage()
		item.inventory.removeItem(item)
		item.discard()

	subject.fusing = false
	subject.clearSpriteMaterial()
	subject.enablePicking()
	CraftingManager.itemAdded(subject)

static func countTypes(subject: Receiver, ofItems: Array) -> Dictionary:
	var typesDict = {}
	for type in subject.Type:
		typesDict[subject.Type[type]] = 0

	for item in ofItems:
		for type in item.getTypes():
			typesDict[type] += 1

	return typesDict

static func insertCounter(subject: Receiver, text: String, keyword: String, amount: int) -> String:
	var counter = Util.tra("Rainbow Orb_Counter").replace("$num", Util.highlight(amount))
	text = text.replace("$" + keyword, counter)
	return text

static func pve_stat(subject: Receiver, key: String) -> float:
	var stats: Dictionary = subject.get_meta("pve_preview", {})
	if not stats.has(key):
		stats = Expedition.bridge.definition_stats(str(subject.get_meta("pve_definition_id", "")))
	return float(stats.get(key, 0.0))
