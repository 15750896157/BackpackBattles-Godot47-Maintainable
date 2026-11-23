extends "res://Code/Runtime/Compatibility/GameRunCompatibility.gd"

## Original inventory, menu, tooltip and input APIs used by scene nodes.

func openedMenu():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").openedMenu(self)

func closeMenu(restoreVisibility = true):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").closeMenu(self, restoreVisibility)

func onSceneVisibilityChanged(node):
	sceneVisibility[node] = node.visible

func isMenuOpen() -> bool:
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").isMenuOpen(self)

func onItemListClosed():
	itemListOpened = false
	emit_signal("item_list_closed")

func isTouchScreenActive() -> bool:
	return usingTouchscreen

func globalPosToScreenPos(pos) -> Vector2:
	return load("res://Code/Runtime/Behavior/Game/Session.gd").globalPosToScreenPos(self, pos)

func moveMouse(by: Vector2):
	var curMousePos = globalPosToScreenPos(get_global_mouse_position())
	Input.warp_mouse(curMousePos + by)

func moveMouseTo(pos: Vector2):
	Input.warp_mouse(globalPosToScreenPos(pos))

func unhoverAndHideTooltips():

	unlockTooltip()
	unhoverAllItems()
	hideTooltips()
	hideSockets()

func hideTooltips():
	for node in get_tree().get_nodes_in_group("Tooltip"):
		node.hide()

func deleteDraggedItem():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").deleteDraggedItem(self)

func cancelSwitch():
	return

func showAffectedLines():
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").showAffectedLines(self)

func clearAffectedLines():
	for line in affectedLines:
		ObjectPool.returnInstance(line)
	affectedLines.clear()

func onInventoryShifted(shift: Vector2):
	cancelSwitch()

	for line in affectedLines:
		line.moveBy(shift)

	setTutorialDone(TutorialSteps.Shift)

func setInventoryEditMode(editMode):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").setInventoryEditMode(self, editMode)

func onEditModeAniFinished(ani):
	if ani == curEditModeAni:
		curEditModeAni = null

func setItemEditMode(item, isInGridStorage = null):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").setItemEditMode(self, item, isInGridStorage)

func lockTooltip(item):
	return load("res://Code/Runtime/Behavior/Game/Presentation.gd").lockTooltip(self, item)

func unlockTooltip():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").unlockTooltip(self)

func onItemUnderMouse(item):
	itemsUnderMouse.push_back(item)

func onItemUnderMouseExited(item):
	if item in itemsUnderMouse:
		itemsUnderMouse.erase(item)

func encode(g: int) -> int:
	return (g + (g << 32)) ^ randnum

func encode_static(g: int) -> int:
	return g ^ 2345345

func decode_static(g: int) -> int:
	return encode_static(g)

func decode(g: int) -> int:
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").decode(self, g)

func getGold() -> int:
	return decode(gold_internal)

func setGoldEncoded(amount):
	gold_internal = encode(amount)
	gold = decode(gold_internal)

func setGold(amount):
	var oldGold = decode(gold_internal)
	setGoldEncoded(amount)
	emit_signal("gold_changed", amount - oldGold)

func spendGold(amount):
	setGoldEncoded(decode(gold_internal) - amount)
	emit_signal("gold_changed", - amount)

func gainGold(amount):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").gainGold(self, amount)

func shootGold(fromPos, toPos, amount):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").shootGold(self, fromPos, toPos, amount)

func getCoinPlayerLayer() -> int:
	return Game.playerNode.z_index + 20

func getCoinSellboxLayer() -> int:
	return Util.getGlobalZ(Game.SELLBOX) + 3

func itemPickedUp(item):
	cancelSwitch()
	draggedItem = item
	emit_signal("item_picked_up")
	if item.isBag():
		onBagMoved()

func itemDropped(item, dropResult):
	lastItemDropTime = Util.time
	emit_signal("item_dropped", item, dropResult)
	if draggedItem == item:
		draggedItem = null
	PLAYER.INVENTORY.cleanUp()

func onInventoryChanged():
	emit_signal("inventory_changed")

func getCombatOrReplayTime() -> float:
	if fightEnded:
		return combatLog.replayTime
	else:
		return combatTimer.combatTime

func tooltipsEnabled():
	return TOOLTIPS and not SELECTING and Util.getFrameCounter_process() > tooltipDisableFrameCounter

func disableTooltipsFor(frames):
	tooltipDisableFrameCounter = Util.getFrameCounter_process() + frames

func hoverResponseEnabled():
	return TOOLTIPS and not SELECTING and Util.getFrameCounter_process() > hoverResponseDisabledFramecounter

func disableHoverResponsesFor(frames):
	hoverResponseDisabledFramecounter = Util.getFrameCounter_process() + frames

func unhoverAllItems(clearItemsUnderMouse = true):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").unhoverAllItems(self, clearItemsUnderMouse)

func refocusHoveredItem():
	if hoveredItems.is_empty(): return
	hoveredItems[0].gainFocus()
	emit_signal("item_gained_focus", hoveredItems[0])

func hasHoverFocus(item):

	if draggedItem != null:
		return draggedItem == item

	if hoveredItems.is_empty(): return false

	return hoveredItems[0] == item

func getFocusItem():
	if draggedItem != null:
		return draggedItem

	if not hoveredItems.is_empty():
		return hoveredItems[0]

	return null

func itemHovered(item):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").itemHovered(self, item)

func recalcHoverPriority():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").recalcHoverPriority(self)

func itemHoverEnd(item):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").itemHoverEnd(self, item)

func isInsideDraggedItem(item):
	return draggedItem and item in draggedItem.draggedInsideItems

func onItemBought(item, onSale):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").onItemBought(self, item, onSale)

func onSpecialItemBought(item):

	SteamHelper.updateRichPresence()
	emit_signal("special_item_bought", item)

	PLAYER.levelUp()
	Sound.playSound(specialItemBoughtSound)

func onItemSold(item):
	emit_signal("item_sold", item)

func onItemRotated():
	persistent["rotations"] += 1
	setTutorialDone(TutorialSteps.Rotate)

func getTotalRotations():
	return persistent["rotations"]

func onItemLocked():
	setTutorialDone(TutorialSteps.Lock)

func onItemReserved():
	setTutorialDone(TutorialSteps.Reserve)

func onBagMoved():
	setTutorialDone(TutorialSteps.BagMove)

func getNumCrafted(itemName):
	var index = ItemBook.getItemIndex(itemName)
	return persistent["craftedRecipes"].get(index, 0)

func onCraftingTimeout():
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").onCraftingTimeout(self)

func onItemCrafted(itemDescriptor: ItemDescriptor):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").onItemCrafted(self, itemDescriptor)

func onCraftingFinished():
	emit_signal("item_crafting_finished")

func getNumCraftedItems():
	return persistent["crafted"]

func revealRecipe(itemDescriptor):
	var index = ItemBook.getItemIndex(itemDescriptor.getName())
	persistent["craftedRecipes"][index] = RECIPE_REVEALED
	saveGame()

func isRecipeRevealed(itemName):
	var index = ItemBook.getItemIndex(itemName)
	return persistent["craftedRecipes"].get(index, 0) == RECIPE_REVEALED

func onCraftingReady(item):
	emit_signal("crafting_ready")

func isTutorialDone(step: int) -> bool:
	return (persistent["tutorial"] & step) > 0

func setTutorialDone(step: int):
	if persistent["tutorial"] & step == 0:
		persistent["tutorial"] |= step
		emit_signal("tutorial_done", step)

func getNextTutorialText():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").getNextTutorialText(self)

func onDecorationDestructed():
	shopKeeper.onDecorationDestructed()
	SteamHelper.unlockAchievement("Destruct", true)

func changeArrowCursor(cursorTypeArrow):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeArrow],
		Input.CURSOR_ARROW, getCursorOffset(cursorTypeArrow))

func changeHandCursor(cursorTypeHand):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeHand],
	Input.CURSOR_POINTING_HAND, getCursorOffset(cursorTypeHand))

func changeVSizeCursor(cursorTypeVSize):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeVSize],
	Input.CURSOR_VSIZE, getCursorOffset(cursorTypeVSize))

func changeHSizeCursor(cursorTypeHSize):
	Input.set_custom_mouse_cursor(scaledCursors[cursorTypeHSize],
	Input.CURSOR_HSIZE, getCursorOffset(cursorTypeHSize))

func getCursorOffset(cursorType) -> Vector2:
	var offset=Vector2(5,2) if cursorType<6 else cursorOffsets[cursorType]
	return offset * (float(scaledCursors[cursorType].get_width())/float(cursors[cursorType].get_width()))

func changeCursorSize(newSize: float):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").changeCursorSize(self, newSize)

func onHoverInteractable(control: Node):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").onHoverInteractable(self, control)

func onHoverInteractableEnd(control):
	if hoveredInteractable == control:

		hoveredInteractable = null

func onClickButton():
	if Util.clockTime > 3.0:
		Sound.playSound_process(clickButtonSound, 3)

func recalculateCursor():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").recalculateCursor(self)

func getCursorType():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").getCursorType(self)

func getSoftwareCursor():
	return (cursor == Cursor.SOFTWARE_SMALL or
			cursor == Cursor.SOFTWARE_LARGE or
			SteamHelper.STEAMDECK)

func addControlOfInterest(control: Control, offset: Vector2 = Vector2.ZERO,
	scrollContainer = null, childToScrollTo = null, layer = 0):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").addControlOfInterest(self, control, offset, scrollContainer, childToScrollTo, layer)

func addPointOfInterest(pos: Vector2, scrollContainer = null,
	childToScrollTo = null, layer = 0):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").addPointOfInterest(self, pos, scrollContainer, childToScrollTo, layer)

func addItemOfInterest(item, layer = 0):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").addItemOfInterest(self, item, layer)

func addOcclusionRect(rect: OcclusionRect):
	warpPointOcclusionRects.push_back(rect)

func addOcclusion(topLeft: Vector2, size: Vector2, layer: int):
	warpPointOcclusionRects.push_back(OcclusionRect.new(topLeft, size, layer))

func connectToGetRectsSignals(receiver: Node, method: String):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").connectToGetRectsSignals(self, receiver, method)

func connectToWarpCursorSignals(receiver: Node, method: String):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").connectToWarpCursorSignals(self, receiver, method)

func warp(input):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").warp(self, input)

func ensureScrollVisibility(scrollContainer: ScrollContainer, child):
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").ensureScrollVisibility(self, scrollContainer, child)

func typeToKeyword(_type):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").typeToKeyword(self, _type)

func showSockets():
	var sockets = get_tree().get_nodes_in_group("Socket")
	for s in sockets:
		s.showSocket()

func hideSockets():

	var sockets = get_tree().get_nodes_in_group("Socket")
	for s in sockets:
		s.hideSocket()

func showWarning(textKey, confirmKey, cancelKey):
	return load("res://Code/Runtime/Behavior/Features/Core/GameBehavior.gd").showWarning(self, textKey, confirmKey, cancelKey)

func onPatchNotesClosed():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").onPatchNotesClosed(self)

func fuseAll():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").fuseAll(self)

func checkForInventoryAchievements():
	return load("res://Code/Runtime/Behavior/Game/ProgressAndRewards.gd").checkForInventoryAchievements(self)
