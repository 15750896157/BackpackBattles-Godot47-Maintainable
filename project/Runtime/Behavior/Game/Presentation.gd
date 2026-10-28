extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Game.gd")

static func switchToCombat(subject: Receiver):
	if Expedition.enabled:
		var ticket = await Expedition.art.curtain.cover("shop_to_combat")
		var epoch = Expedition.view_epoch
		InputBlocker.activate(InputBlocker.Source.Streaming, false)
		var ready = await Expedition.scenery.ensure_view("combat")
		InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
		if not ready or epoch != Expedition.view_epoch:
			await Expedition.art.curtain.reveal(ticket)
			return

	subject.canCancelSwitch = not Expedition.enabled
	if Expedition.enabled:
		subject.canSwitchToCombat = false
		InputBlocker.activate(InputBlocker.Source.SceneSwitch)
		subject.call_deferred("unhoverAndHideTooltips")

	var pos = 0
	if subject.startCombatButtonAni.current_animation == "TurnAround":
		pos = subject.startCombatButtonAni.current_animation_position

	subject.sceneAnimation.speed_scale = 1
	subject.sceneAnimation.play("ShopToCombat")

	if pos == 0:
		subject.sceneAnimation.advance(0.017)
	else:
		subject.sceneAnimation.seek(pos)

	subject.setInventoryEditMode(subject.InventoryEditMode.Default)

	subject.emit_signal("combat_start_pressed")

static func forceSwitchToCombat(subject: Receiver):
	if not subject.canSwitchToCombat:
		print("Attempted switch to combat")
		return
	subject.closeAllMenus()
	subject.unhoverAndHideTooltips()
	subject.switchToCombat()
	subject.canSwitchToCombat = false

	InputBlocker.activate(InputBlocker.Source.Lobby)
	for control in subject.get_tree().get_nodes_in_group("PinnedControl"):
		InputBlocker.restoreControl(InputBlocker.Source.Lobby, control)

	RunDatabase.lobbies.prepareCombat()

	if not RunDatabase.lobbies.allOpponentsSubmitted():
		subject.sceneAnimation.stop(false)
		RunDatabase.lobbies.connect("found_opponent", Callable(subject, "finishForceSwitchToCombat").bind(), subject.CONNECT_ONE_SHOT)
		Util.callDelayed_process(subject, "onWaitingForMembersTimeout", 5)
	else:
		subject.finishForceSwitchToCombat()

static func onWaitingForMembersTimeout(subject: Receiver):
	if not RunDatabase.lobbies.isInLobby(): return

	var membersList = ""
	var missing = RunDatabase.lobbies.getMissingOpponentNames()
	if missing.is_empty():

		return

	for i in missing.size():
		membersList += missing[i]
		if i != missing.size() - 1:
			membersList += "\n"

	if RunDatabase.lobbies.isHost():
		Util.showPopupMessage("HINT_WaitingForMembers", {"members": membersList}, 5)
	else:
		print("Offline members: ", membersList)

static func forceLeaveLobby(subject: Receiver):
	Util.tryDisconnect(RunDatabase.lobbies, "found_opponent", subject, "finishForceSwitchToCombat")
	InputBlocker.deactivate(InputBlocker.Source.Lobby)

	if not RunDatabase.lobbies.isInLobby():
		print("not in lobby")
		return

	if subject.sceneAnimation.current_animation != "":
		subject.leaveLobbyPending = true
		print("forceLeaveLobby 1")
		return

	if subject.state == subject.State.Title:
		subject.leaveLobbyPending = false
		RunDatabase.lobbies.leaveLobby()
		print("forceLeaveLobby 2")
		return

	subject.closeAllMenus()

	if subject.state == subject.State.Shop:
		subject.leaveLobbyFromShop()
		print("forceLeaveLobby 3")

	elif subject.state == subject.State.Combat:
		RunDatabase.lobbies.leaveLobby()
		if subject.fightEnded:
			subject.combatSceneNode.forceSwitchToTitle()
			print("forceLeaveLobby 4")

		else:
			subject.leaveLobbyPending = true
			print("forceLeaveLobby 5")

static func initOpponent(subject: Receiver, roundReduction, droppedItems):
	var roundData = RunDatabase.getNextOpponentData(roundReduction)
	subject.OPPONENT.INVENTORY.reset()
	ItemBook.opponentItems.clear()
	subject.OPPONENT.setMaxHealth(roundData["health"])
	subject.OPPONENT.setMaxStamina(roundData["stamina"])
	subject.OPPONENT.setClass(roundData["class"], subject.getShowChibis() and roundData["chibi"])

	var dropIndex = - 1

	if not "reflection" in roundData:
		if droppedItems >= 1:
			dropIndex = Util.rng.randi_range(0, roundData["items"].size() - 1)
	else:
		pass

	roundData["items"].sort_custom(Callable(subject.ItemSort, "sort_BagOrder"))

	var itemIndex = 0
	var checkValidity = not "reflection" in roundData

	for tuple in roundData["items"]:
		var descriptor = tuple["d"]
		itemIndex += 1

		if itemIndex == dropIndex + 1:
			if descriptor.isBag() or descriptor.isWeapon():
				dropIndex += 1
			else:

				continue

		var item = ItemBook.instantiateItem(descriptor)
		var result = subject.addOpponentItem(tuple, item, checkValidity)
		if result == - 1:
			return - 1

	for slot in roundData["skins"].size():
		var skinId = roundData["skins"][slot]

		if roundData["chibi"] and not subject.getShowChibis():
			skinId = SkinBook.getRandomSkinFor(roundData["class"], 1, slot).id

		subject.OPPONENT.sprite.setSkin(slot, skinId)

	subject.OPPONENT.setCharacterName(roundData["name"])
	if Settings.getVal(Settings.Setting.hide_names):
		subject.OPPONENT.hideCharacterName()

	subject.curOpponentData = roundData
	return 0

static func initHistoryOpponent(subject: Receiver):

	var data = subject.buildHistory.markedOpponentData
	var roundI = subject.buildHistory.markedOpponentRound

	var roundData: BuildHistoryData.RoundData = data.getRoundData(roundI)
	subject.OPPONENT.INVENTORY.reset()
	subject.OPPONENT.setMaxHealth(roundData.health)
	subject.OPPONENT.setMaxStamina(roundData.stamina)
	subject.OPPONENT.setClass(data.classI, false)

	var deserialized = RunData.deserializeItems(roundData.items,
		data.getVersionString())

	var items = deserialized["items"]
	items.sort_custom(Callable(subject.ItemSort, "sort_BagOrder"))

	var itemIndex = 0
	for tuple in items:
		var descriptor = tuple["d"]
		var item = ItemBook.instantiateItem(descriptor)
		var result = subject.addOpponentItem(tuple, item, true)
		if result == - 1:
			return - 1

	for slot in subject.SkinSlot.size():
		subject.OPPONENT.sprite.setSkin(slot, 0)

	subject.OPPONENT.baseMaxStamina = 5
	subject.OPPONENT.recalculateMaxStamina()
	subject.OPPONENT.setCharacterName(Util.tra("BUTTON_BuildHistory"))
	return 0

static func addOpponentItem(subject: Receiver, tuple, item, checkValidity: bool):
	item.ownerType = Item.Owner.Opponent
	subject.opponentNode.add_child(item)
	var topLeftCellPos = tuple["c"]
	var faceDirection = tuple["f"]
	subject.OPPONENT.INVENTORY.orientItem(item, topLeftCellPos, faceDirection)

	if checkValidity:
		if not subject.OPPONENT.INVENTORY.canAddItemOrBag(item):
			if subject.curMode == subject.Mode.History and subject.buildHistory.markedOpponentData != null:
				item.discard()
				print("History entry corrupted")
			else:
				item.discard()
				Util.eprint("Encountered sus run. 8")
				RunDatabase.notifyOpponentCorrupt()

				return - 1

	subject.OPPONENT.INVENTORY.addItemByTopLeft(item, topLeftCellPos)
	item.disablePicking()

	if "g" in tuple:
		var gems = tuple["g"]
		for i in gems.size():
			var gemIndex = gems[i]
			if gemIndex != RunDatabase.emptySocketId:
				var gem = ItemBook.instanciateGemFromIndex(gemIndex)
				item.setGem(i, gem)

	if "pd" in tuple:
		item.setData(tuple["pd"])

	return 0

static func _input(subject: Receiver, event: InputEvent) -> void :
	if event.is_echo(): return

	if not subject.isWeb:
		if Util.isAction_event(event, "grab_item"):

			subject.left_click = event.pressed

	if event is InputEventScreenTouch:
		subject.usingTouchscreen = true

		if not event.pressed and event.index == subject.draggingFinger:
			subject.draggingFinger = - 1

		if event.pressed and subject.draggingFinger == - 1 and subject.draggedItem:
			subject.draggingFinger = event.index

	if subject.usingController:
		if (event is InputEventKey or event is InputEventMouseButton):
			subject.usingController = false
			subject.activeControllerDevice = - 1
			subject.emit_signal("input_changed")

	if (event is InputEventJoypadButton or
				(event is InputEventJoypadMotion and event.axis_value > 0.5)):
		if not subject.usingController:
			subject.usingController = true
			subject.activeControllerDevice = event.device
			subject.emit_signal("input_changed")
		elif subject.activeControllerDevice != event.device:
			subject.activeControllerDevice = event.device
			subject.emit_signal("device_changed")

	if event.is_action_pressed("toggle_fullscreen"):
		if ((subject.get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (subject.get_window().mode == Window.MODE_FULLSCREEN)):
			Settings.setVal(Settings.Setting.window_mode, "windowed")
		else:
			Settings.setVal(Settings.Setting.window_mode, "fullscreen")

	if subject.RECIPE_TOOLTIPS_ENABLED:
		if (subject.lockedTooltipItem != null and event.is_pressed() and
			(event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton)):

				if subject.itemLibrary.isOpen:
					var focusItem = subject.getFocusItem()
					if (focusItem != null and
						focusItem.ownerType == Item.Owner.Tooltip and
						focusItem.owningBuildIntoRecipesTooltip != null):
						subject.itemLibrary.call_deferred("setSpotlightDescriptor", focusItem.descriptor)

				subject.showHintsIsPressed = false
				subject.unlockTooltip()
				subject.get_viewport().set_input_as_handled()

		if Util.isActionPressed_event(event, "show_hints") and subject.tooltipsEnabled():
			subject.showHintsIsPressed = true
			var focusItem = subject.getFocusItem()
			if focusItem != null:
				focusItem.previewCanAffect()

				if focusItem.canShowBuildIntoRecipesTooltip():
					focusItem.showBuildIntoRecipesTooltip()

					if Util.getFrameCounter_process() - subject.showHintsTimeStamp < 20:
						subject.lockTooltip(focusItem)

					subject.showHintsTimeStamp = Util.getFrameCounter_process()
			else:
				subject.showAffectedLines()

		elif Util.isActionReleased_event(event, "show_hints"):
			subject.clearAffectedLines()

			if subject.lockedTooltipItem == null:
				subject.showHintsIsPressed = false
				var focusItem = subject.getFocusItem()
				if focusItem == null:
					focusItem = subject.itemLibrary.getSpotlightItem()
				if focusItem != null:
					focusItem.clearCanAffectVisuals()
					if focusItem.canShowBuildIntoRecipesTooltip():
						focusItem.hideBuildIntoRecipesTooltip()

static func showAffectedLines(subject: Receiver):

	if not subject.affectedLines.is_empty(): return
	if subject.lockedTooltipItem != null: return
	if subject.combatSceneNode.isPostCombatScreenVisible() or subject.isMenuOpen(): return

	var inventories = [subject.PLAYER.INVENTORY]
	if subject.OPPONENT != null:
		inventories.push_back(subject.OPPONENT.INVENTORY)
	for inv in inventories:
		for item in inv.getItems():
			if not item.isBag():
				for color in Item.Affected.values():
					var affectedPoints = inv.getAffectedPoints(item, color)
					for point in affectedPoints:

						var line = ObjectPool.instantiate(subject.affectsLineScene)

						line.setPositions(item, point)
						line.setColor(color)
						subject.affectedLines.push_back(line)

	subject.affectedLines.sort_custom(Callable(subject.LineSort, "sort"))
	for line in subject.affectedLines:
		subject.UINode.add_child(line)

static func setInventoryEditMode(subject: Receiver, editMode):
	if subject.draggedItem != null: return
	if subject.inventoryEditMode == editMode: return

	subject.inventoryEditMode = editMode

	var items = ItemBook.getInventoryStorageShopItems()
	for item in items:
		subject.setItemEditMode(item)

	if subject.inventoryEditMode == subject.InventoryEditMode.Default:
		subject.PLAYER.INVENTORY.pushFloatingItemsToStorage()

	if subject.EDITOR:
		if subject.curEditModeAni != null:
			subject.curEditModeAni.disappear()

		if not subject.UINode.get_node("Toolbar").isOpen:
			subject.curEditModeAni = ObjectPool.instantiate(subject.editModeAnimation)
			subject.UINode.add_child(subject.curEditModeAni)
			subject.curEditModeAni.onEditModeChanged(subject.inventoryEditMode)
			subject.curEditModeAni.position = Vector2(550, 1020)

	subject.emit_signal("edit_mode_changed")

static func lockTooltip(subject: Receiver, item):
	subject.lockedTooltipItem = item
	subject.cancelSwitch()
	if subject.lockedTooltipItem.buildIntoRecipesTooltip != null:
		subject.lockedTooltipItem.buildIntoRecipesTooltip.onTooltipLocked()

	subject.unhoverAllItems(false)

	InputBlocker.disableAllControls(InputBlocker.Source.LockedTooltip, subject.shopSceneNode)
	InputBlocker.disableAllControls(InputBlocker.Source.LockedTooltip, subject.playerNode)
	InputBlocker.disableAllControls(InputBlocker.Source.LockedTooltip, subject.buildHistory)
	InputBlocker.disableAllControls(InputBlocker.Source.LockedTooltip, subject.combatSceneNode)
	InputBlocker.disableAllControls(InputBlocker.Source.LockedTooltip, subject.itemLibrary)

static func addTranslation(subject: Receiver):
	for sheet in ["Keywords", "Items", "ExclusiveItems", "Unreleased", "Interface", "Full"]:
		for locale in ["en", "de"]:
			TranslationServer.add_translation(load("res://Sheets/CSV/" + sheet + "." + locale + ".translation"))

static func _unhandled_input(subject: Receiver, event: InputEvent) -> void :
	if InputBlocker.isActive(): return

	if ( not subject.draggedItem and
		Util.isActionPressed_event(event, "grab_item") and
		not subject.isMenuOpen() and
		Engine.time_scale > 0):

		var particles = ObjectPool.particleOneShot(subject.clickParticles, subject.UINode)
		var pos = Util.getMousePosInWindow() - Vector2(10, 10)
		particles.global_position = pos
		Sound.playSound(subject.clickSound, - 4, Util.rng.randf_range(0.8, 1.0))
		particles.self_modulate = Color.WHITE

	if (event.is_action_pressed("open_library") and
		not subject.isMenuOpen() and subject.state != subject.State.Combat):
			if Expedition.enabled: Expedition.show_codex()
			else: subject.itemLibrary.open()

static func becomeOpponent(subject: Receiver):
	var dur = 0.5
	var offset = subject.OPPONENT.INVENTORY.global_position.x - subject.PLAYER.INVENTORY.global_position.x

	var inventoryTween = subject.create_tween().set_parallel()
	subject.addSwitchAniTween(inventoryTween, subject.PLAYER, offset + subject.oppoBonusOffset, subject.switchAniParableOffset, dur)
	subject.addSwitchAniTween(inventoryTween, subject.OPPONENT, - offset, - subject.switchAniParableOffset, dur)

	inventoryTween.tween_callback(Callable(subject, "finishBecomeOpponent").bind(offset)).set_delay(dur)

	var ani = ObjectPool.instantiate(subject.switchAni)
	subject.UINode.add_child(ani)
	ani.get_node("AnimationPlayer").play("Switch")

static func finishBecomeOpponent(subject: Receiver, offset):

	subject.PLAYER.INVENTORY.global_position.x -= offset + subject.oppoBonusOffset
	subject.OPPONENT.INVENTORY.global_position.x = 100000

	for item in subject.OPPONENT.INVENTORY.getItems():
		item.global_position.x = 100000

	var oldItems = subject.PLAYER.INVENTORY.getItems().duplicate()

	var itemTuples = subject.curOpponentData["items"]
	subject.PLAYER.INVENTORY.createFromItemTuples(itemTuples, Item.Owner.PlayerInventory)

	for item in oldItems:
		item.onRemoveFromInventory()

static func becomeOpponent_old(subject: Receiver):

	var newInv = subject.OPPONENT.INVENTORY
	var oldInv = subject.PLAYER.INVENTORY

	var dif = oldInv.global_position - newInv.global_position

	subject.OPPONENT.INVENTORY = oldInv
	subject.PLAYER.INVENTORY = newInv
	subject.opponentNode.remove_child(newInv)
	subject.playerNode.add_child(newInv)
	newInv.position = Vector2(subject.PLAYER.position.x - 300, 60)
	newInv.character = subject.PLAYER

	for item in newInv.getItems():
		item.ownerType = Item.Owner.PlayerInventory
		subject.opponentNode.remove_child(item)
		subject.playerNode.add_child(item)
		item.position += dif
		item.resetZ()

	for item in oldInv.getItems():
		item.ownerType = Item.Owner.Opponent

static func pve_close_legacy_menus(subject: Receiver, clear_transition: bool):
	if subject.pve_closing_legacy_menus: return
	subject.pve_closing_legacy_menus = true
	for menu in [subject.itemLibrary, subject.recipeBook, subject.options, subject.wardrobe, subject.buildHistory, subject.patchNotes, subject.otherModesUI]:
		if not is_instance_valid(menu) or not menu.is_inside_tree(): continue
		var menu_animation = menu.get_node_or_null("AnimationPlayer")
		if "animation" in menu: menu_animation = menu.animation
		if is_instance_valid(menu_animation):
			menu_animation.clear_queue()
			menu_animation.stop()
		if menu == subject.wardrobe:
			menu.emit_signal("closed")
			menu.finishedClosing()
		elif menu == subject.patchNotes: menu.onCloseFinished()
		elif menu.has_method("closed"): menu.closed()
		elif menu.get_parent() != null: menu.get_parent().remove_child(menu)
		if "isOpen" in menu: menu.isOpen = false
	for node in subject.sceneVisibility:
		if is_instance_valid(node) and node.is_connected("visibility_changed", Callable(subject, "onSceneVisibilityChanged")):
			node.disconnect("visibility_changed", Callable(subject, "onSceneVisibilityChanged"))
	subject.sceneVisibility.clear()
	subject.activePauseSources = subject.PauseSource.Unpaused
	subject.get_tree().paused = false
	Engine.time_scale = 1.0
	ShaderClock.set_scale(1.0)
	Sound.setMuffledSound(false)
	for source in [InputBlocker.Source.Popup, InputBlocker.Source.PopupAnimation, InputBlocker.Source.CombatUI, InputBlocker.Source.LockedTooltip, InputBlocker.Source.ItemDragging, InputBlocker.Source.BoxSelect]:
		InputBlocker.deactivate(source)
	if clear_transition: InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
	subject.pve_closing_legacy_menus = false

static func _pve_restore_actor_parents(subject: Receiver):
	for parent in [subject.playerNode, subject.opponentNode]:
		parent.process_mode = Node.PROCESS_MODE_INHERIT
		parent.modulate = Color.WHITE
		parent.show()
	subject.playerNodeAnimation.stop()
	subject.playerNode.position = Vector2.ZERO
	subject.opponentNode.position = Vector2.ZERO
	if is_instance_valid(subject.PLAYER):
		subject.PLAYER.show()
		subject.PLAYER.modulate = Color.WHITE

static func pve_prepare_title(subject: Receiver):
	if not Expedition.enabled: return
	subject.unhoverAndHideTooltips()
	subject.pve_close_legacy_menus()
	subject.combatTimer.combatEnd()
	subject.combatSceneNode.pve_reset_lifecycle()
	subject.freeOpponent()
	subject.sceneAnimation.stop()
	subject._pve_restore_actor_parents()
	if is_instance_valid(subject.PLAYER): subject.PLAYER.pve_reset_presentation("title")
	subject.canSwitchToCombat = false
	subject.canCancelSwitch = false
	subject.fightEnded = true
	Sound.pve_stop_scene_sounds()
	Sound.playBGM(Sound.titleBGM)
	subject.emit_signal("return_to_title")

static func freeOpponent(subject: Receiver):
	if subject.OPPONENT:
		if Expedition.enabled:
			subject.emit_signal("combat_scene_left")
			subject.OPPONENT.combatEnd()
			subject.OPPONENT.opponent = null
			if is_instance_valid(subject.PLAYER): subject.PLAYER.opponent = null
		subject.OPPONENT.INVENTORY.deleteItems()
		if Expedition.enabled and subject.OPPONENT.INVENTORY.get_parent() != null:
			subject.OPPONENT.INVENTORY.get_parent().remove_child(subject.OPPONENT.INVENTORY)
		subject.OPPONENT.INVENTORY.queue_free()
		if Expedition.enabled and subject.OPPONENT.get_parent() != null:
			subject.OPPONENT.get_parent().remove_child(subject.OPPONENT)
		subject.OPPONENT.queue_free()
		subject.OPPONENT = null
		ItemBook.opponentItems.clear()
		subject.curOpponentData.clear()

static func onSceneAnimationFinished(subject: Receiver, aniName):
	if aniName == "TitleToShop":
		subject.state = subject.State.Shop
		subject.canSwitchToCombat = true
		InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
		subject.emit_signal("pre_shop_opened_from_title")
		Expedition.start_round()
		subject.call_deferred("_pve_restore_health")
		subject.emit_signal("run_started")
		subject.emit_signal("shop_opened")
	elif aniName == "ShopToCombat":
		for actor in [subject.PLAYER, subject.OPPONENT]:
			if is_instance_valid(actor):
				if actor.animation.current_animation in ["OpponentInit", "EnterCombatFromShop"]: actor.animation.advance(100)
				actor.pve_set_combat_anchor()
		subject.state = subject.State.Combat
		InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
		subject.emit_signal("combat_scene_entered")
	elif aniName == "CombatToShop":
		subject.state = subject.State.Shop
		subject.canSwitchToCombat = true
		InputBlocker.deactivate(InputBlocker.Source.SceneSwitch)
		subject.emit_signal("pre_shop_opened_from_combat")
		subject.freeOpponent()
		Expedition.start_round()
		subject.call_deferred("_pve_restore_health")
		subject.call_deferred("emit_signal", "shop_opened")
		subject.shopSceneNode.z_index = 10
	return

static func calcRunRating(subject: Receiver, curRating, numWins, numLosses, triesLeft, survival, perfectRunBeforeSurvival):

	var oldLeagueExact = subject.getLeague_exact(curRating)

	var rating = 2 * numWins

	if triesLeft > 0:
		rating -= 0.5 * numLosses
	else:
		rating -= 1.0 * numLosses

	if survival:
		var survivalBonus = 0
		if perfectRunBeforeSurvival:
			survivalBonus += subject.PERFECT_RUN_RATING * 0.5

		if numLosses == 0:
			survivalBonus += subject.PERFECT_SURVIVAL_RATING
		elif triesLeft > 0:
			survivalBonus += subject.SURVIVED_RATING

		if int(oldLeagueExact) >= subject.Leagues.Master:
			survivalBonus *= 0.6

		rating += survivalBonus
	else:
		if numLosses == 0:
			rating += subject.PERFECT_RUN_RATING
		elif triesLeft > 0:
			rating += subject.MAX_WINS_RATING

	var oldRating = curRating
	curRating += rating
	curRating *= subject.ratingDecay
	var change = curRating - oldRating
	if change < 0:
		change *= 0.6
	curRating = oldRating + change * subject.ratingVelo

	var newLeagueExact = subject.getLeague_exact(curRating)
	if int(newLeagueExact) > int(oldLeagueExact):

		var bonusRating = subject.getRatingDifference_forBonus(curRating, newLeagueExact + subject.RANK_UP_BONUS_RANKING / 100.0)

		curRating += bonusRating

	var clampVal = subject.leagueThresholds[subject.Leagues.Grandma + 1] - 0.5
	curRating = clamp(curRating, 0.0, clampVal)

	return curRating
