extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func setGemData(subject: Receiver, gemData):
	for i in gemData.size():
		var data = gemData[i]
		if data != null:
			var index = data[0]
			var gem = ItemBook.instanciateGemFromIndex(index)
			subject.setGem(i, gem)
			var faceDir = data[1]
			gem.setFaceDirectionInstant(faceDir)
			if data.size() >= 3:
				gem.setLocked(data[2], false)

static func getTouchedBagsCounted(subject: Receiver):
	if subject.isBag() or not subject.placed:
		return null
	else:
		var touchedBags = subject.inventory.getBagsInCells(subject.occupiedCells)
		var bagCounter = Dictionary()
		for bag in touchedBags:
			var found = false

			for countedBag in bagCounter:
				if countedBag.descriptor == bag.descriptor:
					bagCounter[countedBag] += bag.getBagMultiplicity(subject)
					found = true

			if not found:
				bagCounter[bag] = bag.getBagMultiplicity(subject)

		return bagCounter

static func playPickupSound(subject: Receiver):
	var pitch = Util.rng.randf_range(0.9, 1.1)
	match subject.descriptor.material:
		subject.Mat.Default:
			Sound.playSound_process(subject.defaultSounds[0], 0, pitch)
		subject.Mat.Wood:
			Sound.playSound_process(subject.woodSounds[0], - 5, pitch)
		subject.Mat.Metal:
			Sound.playSound_process(subject.metalSounds[0], 3, pitch)
		subject.Mat.Leather:
			Sound.playSound_process(subject.leatherSounds[0], 0, pitch)
		subject.Mat.Stone:
			Sound.playSound_process(subject.stoneSounds[0], - 5, pitch)
		subject.Mat.Glass:
			Sound.playSound_process(subject.glassSounds[0], 0, pitch)
		subject.Mat.Squishy:
			Sound.playSound_process(subject.squishySounds[0], 6, pitch)
		subject.Mat.Jewelry:
			Sound.playSound_process(subject.jewelrySounds[1], - 5, pitch)
		subject.Mat.Sand:
			Sound.playSound_process(subject.sandSounds[0], 3, pitch)
		subject.Mat.Paper:
			Sound.playSound_process(subject.paperSounds[0], - 1, pitch)
		subject.Mat.Slime:
			Sound.playSound_process(subject.slimeSounds[0], 0, pitch + 0.2)
		subject.Mat.Fire:
			Sound.playSound_process(subject.fireSounds[0], 0, pitch)
		subject.Mat.Ice:
			Sound.playSound_process(subject.iceSounds[0], 3, pitch)
		subject.Mat.Bird:
			Sound.playSound_process(subject.birdSounds[0], 0, pitch)
		subject.Mat.Dragon:
			Sound.playSound_process(subject.dragonSounds[1], - 6, pitch + 0.3)
		subject.Mat.Leaf:
			Sound.playSound_process(subject.leafSounds[0], 0, pitch)

static func playDropSound(subject: Receiver, volume):
	volume += subject.impactSoundVolume
	var pitch = Util.rng.randf_range(0.9, 1.1)

	match subject.descriptor.material:
		subject.Mat.Default:
			Sound.playSound(subject.defaultSounds[0], volume, pitch)
		subject.Mat.Wood:
			Sound.playSound(subject.woodSounds[1], volume - 5, pitch)
		subject.Mat.Metal:
			Sound.playSound(subject.metalSounds[1], volume, pitch)
		subject.Mat.Leather:
			Sound.playSound(subject.leatherSounds[1], volume, pitch)
		subject.Mat.Stone:
			Sound.playSound(subject.stoneSounds[1], volume, pitch)
		subject.Mat.Glass:
			Sound.playSound(subject.glassSounds[1], volume, pitch)
		subject.Mat.Squishy:
			Sound.playSound(subject.squishySounds[1], volume - 4, pitch)
		subject.Mat.Jewelry:
			Sound.playSound(subject.jewelrySounds[0], volume - 3, pitch)
		subject.Mat.Sand:
			Sound.playSound(subject.sandSounds[1], volume, 3 * pitch)
		subject.Mat.Paper:
			Sound.playSound(subject.paperSounds[1], volume + 2, pitch)
		subject.Mat.Slime:
			Sound.playSound(subject.slimeSounds[1], volume, pitch + 0.2)
		subject.Mat.Fire:
			Sound.playSound(subject.fireSounds[1], volume - 3, pitch)
		subject.Mat.Ice:
			Sound.playSound(subject.iceSounds[1], volume, pitch)
		subject.Mat.Bird:
			Sound.playSound(subject.birdSounds[1], volume, pitch)
		subject.Mat.Dragon:
			Sound.playSound(subject.dragonSounds[0], volume - 3, pitch + 0.3)
		subject.Mat.Leaf:
			Sound.playSound(subject.leafSounds[1], volume, pitch)

static func _input(subject: Receiver, event: InputEvent) -> void :
	if subject.pve_is_view() and Expedition.art!=null and Expedition.art.is_touch_control_event(event):return
	# PvE controller selection is owned by Inventory's bounded grid navigator.
	# The legacy A-button grab/release otherwise picks the mouse-hovered item
	# before that navigator sees the same event, then drops it on release.
	if subject.pve_is_view() and (event is InputEventJoypadButton or (event is InputEventKey and is_instance_valid(Game.PLAYER) and Game.PLAYER.INVENTORY.pve_navigation_active)):
		return
	if subject.pve_is_view() and subject.dragged and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		Expedition.bridge.cancel_drag(subject)
		subject.get_viewport().set_input_as_handled()
		return
	if subject.pve_is_view() and not InputBlocker.isActive() and Expedition.flow.screen_state == "SHOP_PREPARE" and event.is_pressed():
		if Util.isAction_event(event, "grab_item") and Util.isActionPressed("push_to_storage") and subject.canBePicked():
			var result = Expedition.bridge.store_item(subject)
			subject.reactToDropResult(subject.DropResult.AddedToStorageBox if result.ok or bool(result.get("committed_in_memory", false)) else subject.DropResult.OutsideInventory)
			subject.get_viewport().set_input_as_handled()
			return
	if InputBlocker.isActive(): return
	if event is InputEventMouseMotion or event is InputEventJoypadMotion: return
	if event.is_echo(): return

	if (event.is_action_pressed("options") and
		subject.dragged and
		Game.state == Game.State.Shop):
		subject.cancelDrag()
		Game.cancelSwitch()
		subject.get_viewport().set_input_as_handled()
		return

	if Util.isActionPressed_event(event, "push_to_storage"):
		if subject.canBeDropped() and subject.isBag():
			Game.hotswapBehaviorModified = true
			var result = subject.drop()
			Game.hotswapBehaviorModified = false
			subject.reactToDropResult(result)
			Game.cancelSwitch()
			subject.get_viewport().set_input_as_handled()
			return

	var isTouchEvent = event is InputEventScreenTouch

	if (Util.isAction_event(event, "grab_item") or
		isTouchEvent):

		if event.is_pressed():
			if subject.canBePicked():
				if (Game.state == Game.State.Shop and
					Util.isActionPressed("push_to_storage")):
						if subject.ownerType == subject.Owner.PlayerInventory:

							if Game.inventoryEditMode == Game.InventoryEditMode.Default:
								subject.pushItemsInsideToStorage()
							subject.inventory.removeItem(subject)
							subject.pushToStorage(Game.STORAGEBOX.center)
							subject.reactToDropResult(subject.DropResult.AddedToStorageBox)

						elif subject.ownerType == subject.Owner.Shop:

							Util.reparentNode(subject, Game.playerNode)
							subject.collisionMap.hide()
							subject.pushToStorage(Game.STORAGEBOX.center)
							subject.reactToDropResult(subject.DropResult.AddedToStorageBox)
						elif subject.ownerType == subject.Owner.Socket:

							subject.pushToStorage(Game.STORAGEBOX.center)
							subject.reactToDropResult(subject.DropResult.AddedToStorageBox)

						Game.cancelSwitch()
						subject.get_viewport().set_input_as_handled()
						Game.setTutorialDone(Game.TutorialSteps.SendToStorage)

				else:

					if isTouchEvent:
						Game.draggingFinger = event.index
					subject.pickup()

			elif subject.hovered_state and not subject.pickingEnabled and subject.ownerType == subject.Owner.Shop:
				if Util.time >= subject.notEnoughGoldLabelReadyTime:
					Game.shopSceneNode.notEnoughGold(subject.global_position)
					subject.notEnoughGoldLabelReadyTime = Util.time + 1
					subject.get_viewport().set_input_as_handled()

			elif subject.focus and subject.ownerType == subject.Owner.ItemLibrary:
				if Game.lockedTooltipItem == null:
					Game.itemLibrary.setSpotlightItem(subject)

			elif subject.focus and subject.ownerType == subject.Owner.InfoPanelIcon:
				subject.emit_signal("info_panel_clicked")

		elif subject.canBeDropped():
			if not isTouchEvent or Game.draggingFinger == event.index:

				var result = subject.drop()
				subject.reactToDropResult(result)

	elif Util.isActionPressed_event(event, "lock_combining"):
		if subject.canBeLocked():
			if subject.locked:
				subject.unlockCombining()
				Game.cancelSwitch()
			else:
				subject.lockCombining()
				Game.onItemLocked()
				Game.cancelSwitch()
			subject.get_viewport().set_input_as_handled()

	if (subject.dragged and
		isTouchEvent and
		event.pressed and
		Game.draggingFinger != event.index and
		Game.draggingFinger != - 1):

			subject.rotateRight()

static func resetSprite(subject: Receiver):
	if subject.pve_is_view():
		Util.finishTween(subject.shadowTween)
		subject.animation.advance(100)
		subject.animation.play("RESET")
		subject.animation.advance(1)
		subject.sprite.position = subject.get_meta("pve_sprite_position", Vector2.ZERO)
		subject.sprite.rotation = 0
		subject.setSpriteScale(subject.spriteScale)
		return
	Util.finishTween(subject.shadowTween)
	subject.animation.advance(100)
	subject.animation.play("RESET")
	subject.animation.advance(1)
	subject.sprite.position = Vector2.ZERO
	subject.sprite.rotation = 0
	subject.sprite.scale = subject.spriteScale

static func shopEntered(subject: Receiver, craft: bool):
	subject.baseCooldownOverride = subject.descriptor.cd
	subject.speedScale = 0.0
	subject.bonusMinDam = 0
	subject.bonusMaxDam = 0
	subject.removableDam = 0
	subject.bonusDamageFactor = 1.0
	subject.staminaFactor = 1.0
	for buff in subject.buffPowers:
		subject.buffPowers[buff] = 1.0
		subject.buffAmplificationChances[buff] = 0.0

	subject.critChancePercent = 0.0
	subject.critTokens = 0
	subject.critSeverity = subject.BASE_CRIT_SEVERITY
	subject.bonusChancePercent_mult = 0.0
	subject.bonusChancePercent_additive1 = 0.0
	subject.bonusChancePercent_additive2 = 0.0
	subject.bonusAccuracy = 0.0
	subject.doubleActivationChance = 0.0
	subject.doubleAttackEffectChance = 0.0
	subject.paramMult.clear()
	subject.paramAdd.clear()
	subject.numCharges = 0
	subject.statDisplayOverrides.fill(null)
	subject.itemMetrics.fill(0)
	subject.consumed = false
	subject.showCooldownSmooth(0)

	subject.enablePicking()
	for gem in subject.getGemsNoNull():
		gem.shopEntered(craft)

	if craft:
		subject.addToCraftingQueue()

	subject.onShopEntered()
