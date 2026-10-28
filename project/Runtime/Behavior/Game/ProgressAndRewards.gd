extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Game.gd")

static func itemHovered(subject: Receiver, item):
	if Util.getFrameCounter_process() < subject.focusDisableFrameCounter:
		return

	var focusItem = null
	if not subject.hoveredItems.is_empty():
		focusItem = subject.hoveredItems[0]

	subject.hoveredItems.push_back(item)

	subject.hoveredItems.sort_custom(Callable(subject.ItemSort, "sort_HoverPriority"))

	if subject.hoveredItems[0] != focusItem:

		if focusItem != null:
			focusItem.loseFocus()

		subject.emit_signal("item_gained_focus", subject.hoveredItems[0])

static func onItemBought(subject: Receiver, item, onSale):
	subject.emit_signal("item_bought", item, onSale)
	if Util.rng.randf() < 0.1:
		subject.PLAYER.playSound(subject.classResources[subject.curClass].getBuySound(), 4)

	subject.incrementItemStatistic(Game.ItemStatistic.Acquired, item.descriptor)
	if onSale:
		subject.incrementItemStatistic(Game.ItemStatistic.BoughtOnSale, item.descriptor)

static func onItemCrafted(subject: Receiver, itemDescriptor: ItemDescriptor):
	var index = itemDescriptor.getIndex()
	var prevAmount = subject.persistent["craftedRecipes"].get(index, 0)
	if prevAmount == subject.RECIPE_REVEALED:

		prevAmount = 0
	subject.persistent["craftedRecipes"][index] = prevAmount + 1
	subject.persistent["crafted"] += 1
	subject.incrementItemStatistic(Game.ItemStatistic.Acquired, itemDescriptor)

	subject.saveRunState()
	subject.saveGame()
	subject.emit_signal("item_crafted", itemDescriptor)

	if ( not itemDescriptor.getName() == "Goobert" and
		not (itemDescriptor.gateItem == ItemBook.boxOfRichesDescriptor)):

		SteamHelper.unlockAchievement("Crafted" + str(itemDescriptor.itemIndex))

static func getNextTutorialText(subject: Receiver):
	if subject.getNumStartedRuns() > 10: return null

	for i in subject.tutorialPriorities.size():
		subject.currentTutorialStep += 1
		subject.currentTutorialStep %= subject.tutorialPriorities.size()
		var stepI = subject.tutorialPriorities[subject.currentTutorialStep]
		if not subject.isTutorialDone(stepI):
			var stepName = subject.tutorialEncodingToStep[stepI]
			var traKey = "TUTORIAL_" + stepName
			var formatParams = null
			var addController = subject.usingController
			var skip = false

			if subject.usingController:

				match stepI:
					subject.TutorialSteps.Lock:
						formatParams = {"button": Util.getControllerIconBbcode("lock_combining_controller", 40)}
					subject.TutorialSteps.Shift:
						pass
					subject.TutorialSteps.Reserve:
						formatParams = {"uibutton": Util.getControllerIconBbcode("ui_accept"),
						"reservebutton": Util.getControllerIconBbcode("reserve_controller")}
					subject.TutorialSteps.Undo:
						skip = true
					subject.TutorialSteps.ShowRecipes:
						skip = true
					subject.TutorialSteps.SendToStorage:
						skip = true
					_:
						addController = false

			if skip: continue

			if addController:
				traKey += "_CONTROLLER"

			var position: String = Util.tra(traKey)
			if position != "":
				if formatParams != null:
					position = position.format(formatParams)

				return [position, stepI]
	return null

static func changeCursorSize(subject: Receiver, newSize: float):

	for i in subject.cursors.size():

		var unscaledImg: Image = subject.cursors[i]
		var scaledImgTex: ImageTexture = subject.scaledCursors[i]
		var scaledImg: Image = scaledImgTex.get_image()
		scaledImg.copy_from(unscaledImg)

		scaledImg.resize(newSize * unscaledImg.get_width(), newSize * unscaledImg.get_height(), Image.INTERPOLATE_TRILINEAR)
		subject.scaledCursors[i] = ImageTexture.create_from_image(scaledImg)
	subject.recalculateCursor()

static func recalculateCursor(subject: Receiver):
	if subject.isWeb: return

	var cursorType = subject.getCursorType()

	if subject.lastCursorType == cursorType:
		return

	subject.lastCursorType = cursorType

	if subject.getSoftwareCursor():
		if subject.softwareCursor == null:
			subject.softwareCursor = subject.softwareCursorScene.instantiate()
			subject.add_child(subject.softwareCursor)
			if not subject.isWeb:
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	else:
		if subject.softwareCursor != null:
			subject.softwareCursor.queue_free()
			subject.softwareCursor = null
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if subject.cursor == subject.Cursor.HARDWARE_LARGE or subject.cursor == subject.Cursor.HARDWARE_SMALL:

			if Input.get_current_cursor_shape() == Input.CURSOR_ARROW:

				subject.changeHandCursor(cursorType)
				subject.changeArrowCursor(cursorType)
			elif Input.get_current_cursor_shape() == Input.CURSOR_VSIZE:
				subject.changeArrowCursor(cursorType)
				subject.changeVSizeCursor(cursorType)
			elif Input.get_current_cursor_shape() == Input.CURSOR_HSIZE:
				subject.changeArrowCursor(cursorType)
				subject.changeHSizeCursor(cursorType)
			else:
				subject.changeArrowCursor(cursorType)
				subject.changeHandCursor(cursorType)

		elif subject.cursor == subject.Cursor.DEFAULT:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
			Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)

static func getCursorType(subject: Receiver):
	var cursorIndex = subject.CursorTypes.DEFAULT

	if subject.hoveredItems.is_empty() and not subject.draggedItem:
		if Input.get_current_cursor_shape() == Input.CURSOR_VSIZE:
			if subject.left_click:
				cursorIndex = subject.CursorTypes.VSIZE_CLICKED
			else:
				cursorIndex = subject.CursorTypes.VSIZE
		elif Input.get_current_cursor_shape() == Input.CURSOR_HSIZE:
			if subject.left_click:
				cursorIndex = subject.CursorTypes.HSIZE_CLICKED
			else:
				cursorIndex = subject.CursorTypes.HSIZE
		elif Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND:
			if subject.left_click:
				cursorIndex = subject.CursorTypes.CLICKABLE_CLICKED
			else:
				cursorIndex = subject.CursorTypes.CLICKABLE
		else:
			if subject.left_click:
				cursorIndex = subject.CursorTypes.CLICKED
			else:
				cursorIndex = subject.CursorTypes.DEFAULT

	else:
		if subject.left_click:
			cursorIndex = subject.CursorTypes.GRABBED
		else:
			cursorIndex = subject.CursorTypes.GRABBABLE

	return cursorIndex

static func _physics_process(subject: Receiver, delta):
	if subject.usingController and not Expedition.enabled:

		var rightStickInput = Input.get_vector(
			"scroll_left", "scroll_right",
			"scroll_up", "scroll_down")

		var rightStickInputLength = rightStickInput.length()

		if rightStickInputLength < 0.3:
			subject.cursorIsWarping = false
			subject.rightStickWarps = 0
			subject.warpTimestamp_rightStick = 0

		elif rightStickInputLength > 0.5:
			subject.cursorIsWarping = true

		if subject.cursorIsWarping:
			if Engine.get_physics_frames() > subject.warpTimestamp_rightStick:
				var hasWarped = subject.warp(rightStickInput)
				if hasWarped:
					var cd = subject.warpCDFrames_initial if subject.rightStickWarps == 0 else subject.warpCDFrames_rapid
					subject.warpTimestamp_rightStick = Engine.get_physics_frames() + cd
					subject.rightStickWarps += 1

		var leftStickInput = Input.get_vector(
			"move_cursor_left", "move_cursor_right",
			"move_cursor_up", "move_cursor_down")

		if leftStickInput != Vector2.ZERO:
			if leftStickInput.length() > 0.99:
				leftStickInput *= 1.5
			subject.moveMouse(1 / 60.0 * subject.CURSOR_SPEED * leftStickInput * Settings.getVal(Settings.Setting.cursor_speed))

static func addControlOfInterest(subject: Receiver, control: Control, offset: Vector2, scrollContainer, childToScrollTo, layer):

	if control == null:
		Util.eassert()
		return

	if control is Slider:

		var basePos = control.global_position
		basePos.x += control.margin
		basePos.y += control.size.y * control.scale.y * 0.5
		var sliderSteps = min(subject.maxSliderSteps, (control.max_value - control.min_value) / control.step)
		var step = (control.size.x * control.scale.x - 2 * control.margin) / sliderSteps
		for i in sliderSteps + 1:
			subject.addPointOfInterest(basePos + Vector2(step * i, 0),
				scrollContainer, childToScrollTo, layer)
	else:
		subject.addPointOfInterest(control.global_position + (
			control.size * 0.5 * control.scale).rotated(deg_to_rad(control.rotation)) + offset,
			scrollContainer, childToScrollTo, layer)

static func addItemOfInterest(subject: Receiver, item, layer):
	if item.isBag() and item.placed and subject.inventoryEditMode == subject.InventoryEditMode.Default:
		var emptyPoints = item.getEmptyGlobalPositions()
		if not emptyPoints.is_empty():
			subject.addPointOfInterest(emptyPoints[0], null, null, layer)
	else:
		subject.addPointOfInterest(item.getGridStorageProxy().getLockPosition(), null, null, layer)

static func warp(subject: Receiver, input):
	subject.warpPointOcclusionRects.clear()

	if subject.isMenuOpen():
		subject.emit_signal("get_rects_menu")
	elif subject.state == subject.State.Shop:
		subject.emit_signal("get_rects_shop")
	elif subject.state == subject.State.Title:
		subject.emit_signal("get_rects_title")
	elif subject.state == subject.State.Combat:
		subject.emit_signal("get_rects_combat")

	subject.pointsOfInterest.clear()
	subject.pointsOfInterestInfo.clear()

	if subject.isMenuOpen():
		subject.emit_signal("warp_cursor_menu")

	elif subject.state == subject.State.Shop:
		var inv = subject.PLAYER.INVENTORY
		if subject.draggedItem != null:
			subject.addPointOfInterest(subject.STORAGEBOX.center + Vector2(0, 50))
			subject.addPointOfInterest(subject.STORAGEBOX.center - Vector2(0, 150))

			if subject.draggedItem.canBeSold():
				subject.addPointOfInterest(subject.SELLBOX.global_position - Vector2(80, 120))

			if subject.draggedItem.ownerType == Item.Owner.Shop:
				subject.addPointOfInterest(subject.draggedItem.pickupPosition)

			var oldPos = subject.draggedItem.global_position
			var offset = oldPos - subject.draggedItem.getTopLeftGlobal() - subject.draggedItem.halfCellSize

			if subject.draggedItem.isBag():
				for cell in inv.inventoryCells:
					inv.orientItem(subject.draggedItem, cell, subject.draggedItem.faceDirection)
					if inv.canAddBag(subject.draggedItem, false):
						var cellPos = inv.cellToGlobalPos(cell, true)
						subject.addPointOfInterest(cellPos + offset)
			else:
				var checkBags = (subject.inventoryEditMode != subject.InventoryEditMode.ItemLayer)

				for cell in inv.inventoryCells:
					inv.orientItem(subject.draggedItem, cell, subject.draggedItem.faceDirection)
					if inv.canAddItem(subject.draggedItem, false, checkBags):
						var cellPos = inv.cellToGlobalPos(cell, true)
						subject.addPointOfInterest(cellPos + offset)

				if subject.draggedItem.isGem():
					for item in inv.getItems():
						for socket in item.sockets:
							subject.addPointOfInterest(socket.global_position)
					if not subject.gridStorage.visible:
						for item in subject.STORAGEBOX.getItems():
							for socket in item.sockets:
								subject.addPointOfInterest(socket.global_position)

			subject.draggedItem.global_position = oldPos
		else:
			for item in ItemBook.getInventoryStorageShopItems():
				if subject.inventoryEditMode == subject.InventoryEditMode.ItemLayer:
					if item.isBag(): continue
				elif subject.inventoryEditMode == subject.InventoryEditMode.BagLayer:
					if not item.isBag(): continue

				subject.addItemOfInterest(item)

			subject.addControlOfInterest(subject.versionButton, Vector2(50, 0))

			subject.emit_signal("warp_cursor_shop")

	elif subject.state == subject.State.Title:
		for item in subject.PLAYER.INVENTORY.getItemsAndGems():
			subject.addItemOfInterest(item)

		subject.emit_signal("warp_cursor_title")

	elif subject.state == subject.State.Combat:
		subject.emit_signal("warp_cursor_combat")

	var curMousePos = subject.get_global_mouse_position()
	var target: Vector2 = Vector2(960, 540)
	var bestScore: float = - INF
	var anglePunishmentFactor = 2.0
	var targetIndex = - 1
	var inputDir = input.normalized()

	for i in subject.pointsOfInterest.size():
		var point = subject.pointsOfInterest[i]
		var dif = point - curMousePos
		var dist = dif.length()
		if dist < 15:
			continue

		var angle = abs(dif.normalized().angle_to(inputDir))
		if angle > subject.maxWarpAngle:
			continue

		var score = - (1 + (angle * anglePunishmentFactor) / subject.maxWarpAngle)
		score *= dist

		if score > bestScore:
			target = point
			targetIndex = i
			bestScore = score

	if bestScore > - INF:
		if targetIndex in subject.pointsOfInterestInfo:
			var info = subject.pointsOfInterestInfo[targetIndex]
			var compensation = subject.ensureScrollVisibility(
					info[0], info[1])
			target.y += compensation

		subject.moveMouseTo(target)

		var trail = ObjectPool.instantiate(subject.cursorWarpTrail)
		subject.UINode.add_child(trail)
		trail.setPoints(curMousePos, target)
		return true
	return false

static func ensureScrollVisibility(subject: Receiver, scrollContainer: ScrollContainer, child):
	var scrollBefore = scrollContainer.scroll_vertical

	if child is Control:
		scrollContainer.ensure_control_visible(child)

	elif child is Item:
		var rect = scrollContainer.get_global_rect()
		var containerTop = rect.position.y
		var containerBottom = rect.end.y
		var itemHeightRange = child.getHeightRange()
		var scroll = 0
		if itemHeightRange.x < containerTop:
			scroll = itemHeightRange.x - containerTop
		elif itemHeightRange.y > containerBottom:
			scroll = itemHeightRange.y - containerBottom
		scrollContainer.scroll_vertical += scroll

	var scrollAfter = scrollContainer.scroll_vertical
	return scrollBefore - scrollAfter

static func incrementItemStatistic(subject: Receiver, statistic: int, descriptor: ItemDescriptor, increment):
	if not subject.ITEM_STATISTICS_ENABLED: return

	var key = subject.getStatisticsKey(statistic)
	var value = subject.persistent[key][descriptor.getIndex()]
	var newValue = increment if value == null else value + increment
	subject.persistent[key][descriptor.getIndex()] = newValue

	if statistic in subject.statisticIncrements and value != null:
		var sIncrement = subject.statisticIncrements[statistic]
		var before: int = value / sIncrement
		var after: int = newValue / sIncrement
		if after > before:
			subject.addRecord(statistic, descriptor, after * sIncrement)

	return newValue

static func onPatchNotesClosed(subject: Receiver):
	if subject.PLAYTEST: return
	if not "version" in subject.persistent: return

	if subject.versionToInt(subject.persistent["version"]) < subject.versionToInt("1.0.0"):
		if subject.hasPlayedInSeason("1"):
			var popup = subject.rankSeason2Popup.instantiate()
			subject.UINode.add_child(popup)
	elif subject.versionToInt(subject.persistent["version"]) < subject.versionToInt("1.1.0"):
		if subject.hasPlayedInSeason("2"):
			var popup = subject.rankSeason3Popup.instantiate()
			subject.UINode.add_child(popup)

static func fuseAll(subject: Receiver):
	InputBlocker.activate(InputBlocker.Source.Fusing)
	Util.callDelayed(subject, "onCraftingTimeout", Item.PRE_FUSE_DUR_COG + Item.FUSE_DUR)

	var playerItems = subject.PLAYER.INVENTORY.getItemsAndGems()
	for item in playerItems:
		item.addToCraftingQueue()

	subject.sortedCraftingPriorities = Util.sortDict(subject.craftingPriorities)

	for item in subject.sortedCraftingPriorities:
		item.startFusing_inShop()

	subject.craftingPriorities.clear()

static func checkForInventoryAchievements(subject: Receiver):
	var dragons = {}
	var bows = {}
	var books = {}
	var classes = 0
	var numBattleRage = 0
	var numPotions = 0
	var numVampiric = 0
	var numFood = 0
	var numMagic = 0
	var numStaminaWeapons = 0
	var numGemstones = 0
	var numPiggies = 0
	var numAmulets = 0

	for item in subject.PLAYER.INVENTORY.getItems():
		if item.hasTag(Item.Tag.Dragon):
			Util.dictAdd(dragons, item.descriptor)

		if item.hasTag(Item.Tag.Bow):
			Util.dictAdd(bows, item.descriptor)

		if item.hasType(Item.Type.Book):
			Util.dictAdd(books, item.descriptor)

		if item.isBattleRageItem():
			numBattleRage += 1

		if item.hasType(Item.Type.Potion):
			numPotions += 1

		if item.hasType(Item.Type.Vampiric):
			numVampiric += 1

		if item.hasType(Item.Type.Food):
			numFood += 1

		if item.hasType(Item.Type.Magic):
			numMagic += 1

		if item.isWeapon() and item.canUseStamina():
			numStaminaWeapons += 1

		if item.descriptor.gateItem == ItemBook.amuletDescriptor:
			numAmulets += 1

		if item.descriptor in ItemBook.piggies:
			numPiggies += 1

		if item.descriptor.isClassItem():
			classes |= item.descriptor.classes

	for item in subject.PLAYER.INVENTORY.getItemsAndGems():
		if item.isGem():
			numGemstones += 1

	if dragons.size() >= 4:
		SteamHelper.unlockAchievement("Dragons")

	if bows.size() >= 3:
		SteamHelper.unlockAchievement("Bows")

	if numBattleRage >= 8:
		SteamHelper.unlockAchievement("BattleRage")

	if books.size() >= 4:
		SteamHelper.unlockAchievement("Books")

	if Util.countOnes(classes, subject.Classes_Full.size()) >= 4:
		SteamHelper.unlockAchievement("MixedClasses")

	if numPotions >= 6:
		SteamHelper.unlockAchievement("Potions")

	if numVampiric >= 8:
		SteamHelper.unlockAchievement("Vampire")

	if numFood >= 8:
		SteamHelper.unlockAchievement("Food")

	if numMagic >= 8:
		SteamHelper.unlockAchievement("Magic")

	if numStaminaWeapons >= 4:
		SteamHelper.unlockAchievement("ManyWeapons")

	if numAmulets >= 5:
		SteamHelper.unlockAchievement("Amulets")

	if numPiggies >= 5:
		SteamHelper.unlockAchievement("Piggies")

	if numGemstones >= 10:
		SteamHelper.unlockAchievement("Gems")

	var deckArr = ItemBook.getItemsInInventoryOfType(ItemBook.deckOfCardsDescriptor)
	if deckArr.size() == 1:
		if deckArr[0].cards.size() >= 8:
			SteamHelper.unlockAchievement("Cards")

	if ItemBook.getNumInventoryUniques() >= 3:
		SteamHelper.unlockAchievement("Treasure")

static func writeoutState(subject: Receiver):
	if not subject.WRITE_OUT_STATE:
		return

	var locale = TranslationServer.get_locale()
	if locale != "en":
		TranslationServer.set_locale("en")

	var json = {}
	json["inventory"] = []
	for item in subject.PLAYER.INVENTORY.getItems():
		var entry = [item.getTranslatedName(), item.occupiedCells]
		json["inventory"].push_back(entry)

	if subject.state == subject.State.Shop:
		json["shop"] = []
		for item in subject.shopSceneNode.getItems():
			if item == null:
				json["shop"].push_back("")
			else:
				json["shop"].push_back(item.getTranslatedName())
	elif subject.state == subject.State.Combat:
		json["opponent"] = []
		for item in subject.OPPONENT.INVENTORY.getItems():
			var entry = [item.getTranslatedName(), item.occupiedCells]
			json["opponent"].push_back(entry)
	json["timestamp"] = Util.getFrameCounter_process()

	var file = File.new()
	var err = file.open("user://state.json", File.WRITE)
	if err == OK:
		file.store_string(JSON.new().stringify(json))
		file.close()
	else:
		print(err)

	if locale != "en":
		TranslationServer.set_locale(locale)

static func saveWindowSettings(subject: Receiver):
	if not ((subject.get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (subject.get_window().mode == Window.MODE_FULLSCREEN)):
		var windowPos = subject.get_window().position
		var windowSize = subject.get_window().size
		var screen = subject.get_window().current_screen
		subject.setConfigValue("Options", "window_position", windowPos)
		subject.setConfigValue("Options", "window_size", windowSize)
		subject.setConfigValue("Options", "screen", screen)

static func checkProcesses(subject: Receiver) -> bool:
	var output = []

	OS.execute("powershell.exe", ["/C", "get-process | Select-Object ProcessName, mainwindowtitle"], output, true)
	if output.is_empty() or output[0] == "":

		return false

	var foundProcess = false
	foundProcess = output[0].findn("cheatengine") != - 1
	if not foundProcess:
		foundProcess = output[0].findn("cheat engine") != - 1

	if foundProcess:
		print("ERROR_16")
		subject.get_tree().quit()

	subject.call_deferred("joinProcessThread")
	return foundProcess

static func _exit_tree(subject: Receiver):
	subject._begin_shutdown()
	for cursor_shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_VSIZE, Input.CURSOR_HSIZE]:
		Input.set_custom_mouse_cursor(null, cursor_shape)
	subject.scaledCursors.clear()
	for cached_menu in [subject.itemLibrary, subject.recipeBook, subject.options, subject.wardrobe, subject.buildHistory, subject.patchNotes, subject.warning, subject.otherModesUI]:
		if is_instance_valid(cached_menu) and cached_menu.get_parent() == null:
			cached_menu.free()
