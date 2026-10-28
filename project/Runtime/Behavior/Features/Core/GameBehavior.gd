extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Game.gd")

static func versionToInt(subject: Receiver, ver: String) -> int:
	var verAsInt = 0
	var split = ver.split(".")
	verAsInt += int(split[0]) * 1000000
	verAsInt += int(split[1]) * 1000
	verAsInt += int(split[2])
	return verAsInt

static func versionToString(subject: Receiver, ver: int) -> String:
	var major = ver / 1000000
	var minor = (ver % 1000000) / 1000
	var mini = (ver % 1000)
	return str(major) + "." + str(minor) + "." + str(mini)

static func unpause(subject: Receiver, pauseSource: int):

	if subject.activePauseSources == subject.PauseSource.Unpaused: return

	subject.activePauseSources &= ~ pauseSource

	if subject.activePauseSources == subject.PauseSource.Unpaused:
		subject.get_tree().paused = false
		ShaderClock.set_scale(1)
		Engine.time_scale = subject.gameSpeedBeforePause

		AudioServer.set_bus_mute(Sound.MASTER_BUS, false)

		Sound.setMuffledSound(false)
		subject.emit_signal("game_unpaused")

static func openedMenu(subject: Receiver):
	subject.emit_signal("menu_opened")
	for node in [subject.shopSceneNode, subject.titleScreen, subject.combatSceneNode, subject.playerNode]:
		subject.sceneVisibility[node] = node.visible

		node.visible = false
		node.connect("visibility_changed", Callable(subject, "onSceneVisibilityChanged").bind(node))

static func closeMenu(subject: Receiver, restoreVisibility):
	subject.emit_signal("menu_close")

	if restoreVisibility:
		for node in subject.sceneVisibility:
			node.visible = subject.sceneVisibility[node]

			node.disconnect("visibility_changed", Callable(subject, "onSceneVisibilityChanged"))

static func isMenuOpen(subject: Receiver) -> bool:
	if Expedition.enabled and is_instance_valid(Expedition.panel) and Expedition.panel.visible:
		return true
	return (subject.itemLibrary.isOpen or
			subject.recipeBook.isOpen or
			subject.options.isOpen or
			subject.buildHistory.isOpen or
			subject.patchNotes.visible)

static func giveTrophies(subject: Receiver, amount):
	if amount > 0:
		subject.persistent["trophies"] += amount
		subject.emit_signal("trophies_changed")

		var trophiesWon = SteamHelper.changeStat("TrophiesWon", amount)
		if trophiesWon > 10000:
			SteamHelper.unlockAchievement("Trophies")

static func loseTrophies(subject: Receiver, amount):
	assert (amount <= subject.persistent["trophies"])
	if amount > 0:
		subject.persistent["trophies"] -= amount
		subject.emit_signal("trophies_changed")

static func getGoldGain(subject: Receiver, inRound):
	var g = subject.goldGain[inRound - 1]

	if inRound == subject.SUBCLASS_ROUND:
		g += 10

	if subject.SKILLS_ENABLED:
		if inRound == subject.SKILL_ROUND1 or inRound == subject.SKILL_ROUND2:
			g += 5

	return g

static func getHealthGain(subject: Receiver, inRound):
	var curHealthGain: int
	if inRound >= 15:
		curHealthGain = 30
	elif inRound >= 10:
		curHealthGain = 20
	elif inRound >= 5:
		curHealthGain = 15
	else:
		curHealthGain = 10
	return curHealthGain

static func getStartInventoryPrice(subject: Receiver, forClass, loadout):
	var price = 0
	for item in subject.classResources[forClass].getStartingItems(loadout):
		price += ItemBook.getDescriptor(item.itemName).price
	return price

static func getRoundResults(subject: Receiver):
	var results = []
	for i in range(subject.RoundResult.size()):
		results.append(0)

	for result in subject.roundResults:
		results[result] += 1

	return results

static func getSavePath(subject: Receiver, format: String) -> String:
	if SteamHelper.is_init() and SteamHelper.isIDValid():
		var newPath = subject.expandPath(format, SteamHelper.STEAM_ID, subject.FULLVERSION)
		return newPath
	else:
		var oldPath = subject.expandPath(format, null, subject.FULLVERSION)
		return oldPath

static func deleteRunState(subject: Receiver, mode: int):
	var runState = subject.getRunState(mode)
	runState.clear()
	var dir = LegacyDirectory.new()
	dir.remove(subject.getLoadPath(subject.getRunStateFormat(mode)))
	if subject.loadTemp:
		dir.remove(subject.getRunStateTmpPath(mode))

	Util.eprint("runstate deleted")

static func checkItemsValid(subject: Receiver, items: Array) -> bool:
	for itemData in items:
		for i in 3:
			if Util.getArrayElement(itemData, i, null) == null:
				print("Runstate loading error.")
				return false
	return true

static func deleteDraggedItem(subject: Receiver):
	if subject.draggedItem != null:
		print("DELETE")
		subject.hoveredItems.erase(subject.draggedItem)
		subject.draggedItem.discard()
		subject.itemDropped(subject.draggedItem, Item.DropResult.Failed)

		InputBlocker.restoreAllControls(InputBlocker.Source.ItemDragging)

static func defaultPersistentVar(subject: Receiver, varName, defaultVal):

	if defaultVal is Array and varName in subject.persistent:
		var existingArray = subject.persistent[varName]
		for index in existingArray.size():
			defaultVal[index] = existingArray[index]

		subject.persistent[varName] = defaultVal
	else:
		subject.persistent[varName] = subject.persistent.get(varName, defaultVal)

static func getPlayerName(subject: Receiver) -> String:
	if subject.persistent["name"] == "":
		if subject.steamAvailable:
			return subject.limitName(SteamHelper.STEAM_NAME)
		else:
			return Util.tra("PLAYER_UNNAMED")
	return subject.limitName(subject.persistent["name"])

static func getClassName(subject: Receiver, charClass) -> String:
	var role = "alchemist" if charClass == subject.Classes_Full.Reaper else "armorer"
	if Expedition.db != null:
		return Expedition.t(str(Expedition.db.get_row("characters", role).name_key))
	return "Alchemist" if role == "alchemist" else "Armorer"

static func getPveClassDescription(subject: Receiver, charClass) -> String:
	if Expedition.db == null:
		return ""
	var role = "alchemist" if charClass == subject.Classes_Full.Reaper else "armorer"
	return Expedition.t(str(Expedition.db.get_row("characters", role).description_key))

static func getNativeClassColor(subject: Receiver, charClass) -> Color:
	if charClass >= 0 and charClass < subject.classResources.size() and is_instance_valid(subject.classResources[charClass]):
		return subject.classResources[charClass].color
	return Color(1.0, 0.92549, 0.831373)

static func getSeason(subject: Receiver) -> String:
	if Util.laterOrEqual(subject.VERSION, "1.1.0"):
		return "3"
	elif subject.FULLVERSION:
		return "2"
	else:
		return ""

static func getClassesForRandom(subject: Receiver) -> Array:
	var classes = []
	for classI in subject.getNumClasses():
		if subject.isClassUnlocked(classI) and classI != subject.persistent["lastRandomClass"]:
			classes.push_back(classI)
	return classes

static func getRatingFromLeague(subject: Receiver, leagueExact: float) -> float:
	var league = int(leagueExact)
	var subrank = leagueExact - league
	var leftBorder = subject.leagueThresholds[league]
	var rightBorder = subject.leagueThresholds[league + 1]
	var bracketSize: float = rightBorder - leftBorder
	return subrank * bracketSize + leftBorder

static func getRankingDifForStats(subject: Receiver, classI, numWins: int, numLosses: int, numTriesLeft: int, survival: bool):
	var curLeagueExact = subject.getLeague_exact(subject.getPlayerRating(classI))
	var ratingForStats = subject.calcRunRatingForClass(classI, numWins, numLosses, numTriesLeft, survival)
	var newLeagueExact = subject.getLeague_exact(ratingForStats)
	var dif = int(newLeagueExact * 100) - int(curLeagueExact * 100)
	return dif

static func getRankingDifIfConceded(subject: Receiver):
	var classI = subject.arenaRunState["class"]
	if "custom" in subject.arenaRunState:
		if CustomRules.isSwitchModeNoLoad(subject.arenaRunState["custom"]) == CustomRules.SwitchModeState.Ranked:
			classI = null

	return subject.getRankingDifForStats(classI, subject.arenaRunState["wins"], subject.MAX_TRIES, 0,
		subject.arenaRunState["survival"])

static func onReconnectTimeout(subject: Receiver):

	print("Reconnect failed")
	subject.deleteRunStateAndRules(subject.Mode.Lobbies)
	RunDatabase.lobbies.disconnect("lobby_joined", Callable(subject, "onReconnectedToLobby"))
	RunDatabase.lobbies.disconnect("lobby_join_failed", Callable(subject, "onReconnectTimeout"))
	subject.loadArenaRunAndStartOnTitle()

static func addStarOfCourage(subject: Receiver):
	var star = ItemBook.generateItem(ItemBook.starOfCourageDescriptor)
	subject.playerNode.add_child(star)
	var couldAdd = subject.PLAYER.INVENTORY.addItemWherePossible(star)
	if couldAdd:
		star.popIn()
	else:
		star.global_rotation = 0
		star.global_position = subject.STORAGEBOX.center()
		star.pushToStorage()

static func titleToShop(subject: Receiver):
	subject.sceneAnimation.speed_scale = 1
	subject.sceneAnimation.play("TitleToShop")

	InputBlocker.activate(InputBlocker.Source.SceneSwitch)
	subject.PLAYER.titleToShop()
	Sound.playSound(subject.transitionSounds[0])
	subject.playShopBGM()
	subject.emit_signal("switch_to_shop")
	subject.emit_signal("title_to_shop")

static func isItemHandicapStats(subject: Receiver):
	return ((subject.wins == 0 and subject.losses == 2) or
			(subject.wins == 1 and subject.losses == 3) or
			(subject.wins == 2 and subject.losses == 4) or
			(subject.wins == 3 and subject.losses == 4) or
			(subject.wins == 0 and subject.losses == 4))

static func activateItems(subject: Receiver, items):

	subject.emit_signal("combat_start")
	subject.combatTimer.start()

	subject.PLAYER.combatStart()
	subject.OPPONENT.combatStart()

	for item in items:
		item.preCombatStart()

	for item in items:
		item.combatStart()

	for item in items:
		item.postCombatStart()

static func setItemEditMode(subject: Receiver, item, isInGridStorage):
	if isInGridStorage == null:
		isInGridStorage = item.isInGridStorage()
	if isInGridStorage: return

	if subject.inventoryEditMode == subject.InventoryEditMode.BagLayer:
		item.setEditMode(item.isBag())
	elif subject.inventoryEditMode == subject.InventoryEditMode.ItemLayer:
		item.setEditMode( not item.isBag())
	else:
		item.setEditMode(true)

static func unlockTooltip(subject: Receiver):
	if subject.lockedTooltipItem == null: return

	var lockedTooltipItem_ = subject.lockedTooltipItem
	subject.lockedTooltipItem = null
	lockedTooltipItem_.hoverEnd()

	subject.cancelSwitch()
	InputBlocker.restoreAllControls(InputBlocker.Source.LockedTooltip)

	for item in subject.itemsUnderMouse:
		item.hover()

static func printNewNodes(subject: Receiver, node):
	for child in node.get_children():
		if child.has_meta("tag"):
			pass

		else:

			child.set_meta("tag", subject.checkI)

			print(child.get_path())
		subject.printNewNodes(child)

static func addSwitchAniTween(subject: Receiver, tween, character, xMovement: float, yOffset: float, dur):

	Util.moveParable(tween, character.INVENTORY, xMovement, yOffset, dur)

	for item in character.INVENTORY.getItems():

		Util.moveParable(tween, item, xMovement, yOffset, dur)

static func _pve_initialize_role_stats(subject: Receiver):
	while not Expedition.initialized:
		await subject.get_tree().process_frame
	if Expedition.flow.screen_state == "MAIN_MENU" and is_instance_valid(subject.PLAYER):
		subject.PLAYER.pve_apply_role_stats()

static func pve_prepare_shop(subject: Receiver):
	if not Expedition.enabled: return
	subject.unhoverAndHideTooltips()
	subject.pve_close_legacy_menus()
	subject.combatTimer.combatEnd()
	subject.combatSceneNode.pve_reset_lifecycle()
	subject.freeOpponent()
	subject._pve_restore_actor_parents()
	if is_instance_valid(subject.PLAYER): subject.PLAYER.pve_reset_presentation("shop")
	Sound.pve_stop_scene_sounds()
	subject.playShopBGM()

static func pve_prepare_combat(subject: Receiver):
	if not Expedition.enabled: return
	subject.pve_close_legacy_menus(false)
	subject._pve_restore_actor_parents()
	for actor in [subject.PLAYER, subject.OPPONENT]:
		if is_instance_valid(actor):
			actor.pve_reset_presentation("combat")
			actor.pve_set_combat_anchor()

static func _pve_restore_health(subject: Receiver):
	if Expedition.enabled and Expedition.active and is_instance_valid(subject.PLAYER) and Expedition.flow.screen_state == "SHOP_PREPARE":
		subject.PLAYER.setCurrentHealth(float(Expedition.flow.run.health))

static func gainRoundGold(subject: Receiver, curGoldGain, curHealthGain):
	subject.PLAYER.giveMaxHealth(curHealthGain)
	subject.emit_signal("round_start_health_gained", curHealthGain)

	if CustomRules.isSwitchMode():
		subject.setGold(curGoldGain)
	else:
		subject.gainGold(curGoldGain)
	subject.emit_signal("round_start_gold_gained", curGoldGain)

static func getBonusTrophies(subject: Receiver) -> int:
	if subject.survivalMode:
		if subject.wasPerfectSurvival():

			return subject.PERFECT_SURVIVAL_TROPHIES
		elif subject.hasSurvived():

			return subject.SURVIVED_TROPHIES
	else:
		if subject.wasPerfectRun():
			return subject.PERFECT_RUN_TROPHIES
		elif subject.wasMaxWins():
			return subject.MAX_WINS_TROPHIES

	return 0

static func endRun_lobby(subject: Receiver):
	print("Game over (Lobby)")
	subject.trophiesPreRun = subject.getTrophies()
	subject.giveTrophies(subject.wins + subject.getBonusTrophies())
	subject.persistent["totalWins"] += subject.wins
	subject.persistent["runsFinished"] += 1
	subject.lastRunMode = subject.curMode
	subject.onRunEnded()

static func decode(subject: Receiver, g: int) -> int:
	var a = g ^ subject.randnum
	var b = a % subject.decodeOffset
	var c = a >> 32
	if b != c:
		print("ERROR_12")
		subject.get_tree().call_deferred("quit")
	return b

static func gainGold(subject: Receiver, amount):
	var newVal = subject.decode(subject.gold_internal) + amount
	subject.setGoldEncoded(newVal)
	subject.emit_signal("gold_changed", amount)
	if newVal >= 30:
		SteamHelper.unlockAchievement("Rich")

static func shootGold(subject: Receiver, fromPos, toPos, amount):

	var particles = subject.coinParticles.instantiate()
	subject.UINode.add_child(particles)
	particles.global_position = fromPos
	particles.activate(amount, fromPos, toPos)
	Util.callDelayed(particles, "queue_free", 10)

	return particles

static func unhoverAllItems(subject: Receiver, clearItemsUnderMouse):
	subject.reactToHoverEnd = false
	for item in subject.hoveredItems.duplicate():
		item.hoverEnd()
	subject.hoveredItems.clear()
	subject.reactToHoverEnd = true
	if clearItemsUnderMouse:
		subject.itemsUnderMouse.clear()

static func recalcHoverPriority(subject: Receiver):
	var focusItem = null
	if not subject.hoveredItems.is_empty():
		focusItem = subject.hoveredItems[0]

	subject.hoveredItems.sort_custom(Callable(subject.ItemSort, "sort_HoverPriority"))

	if focusItem and subject.hoveredItems[0] != focusItem:
		focusItem.loseFocus()

	subject.refocusHoveredItem()

static func itemHoverEnd(subject: Receiver, item):
	if subject.reactToHoverEnd:
		if subject.hasHoverFocus(item):
			if subject.hoveredItems.size() >= 2:

				subject.hoveredItems[1].gainFocus()
				subject.emit_signal("item_gained_focus", subject.hoveredItems[1])

		subject.hoveredItems.erase(item)

static func onCraftingTimeout(subject: Receiver):
	for item in subject.sortedCraftingPriorities:
		item.finishFusing()
	subject.sortedCraftingPriorities.clear()
	subject.itemsAreFusing = false
	subject.emit_signal("crafting_finished")

	InputBlocker.deactivate(InputBlocker.Source.Fusing)

static func onHoverInteractable(subject: Receiver, control: Node):

	subject.hoveredInteractable = control

	subject.emit_signal("interactable_hovered")

	if Util.clockTime > subject.hoverSoundReadyTime:

		Sound.playRising(subject.hoverSound, - 6, 1, true)
		subject.hoverSoundReadyTime = Util.clockTime + 0.1

static func _process(subject: Receiver, delta: float) -> void :
	if Expedition.enabled and Expedition.preferences != null:
		var contrast = bool(Expedition.preferences.values.get("high_contrast", false))
		if contrast != subject.pve_high_contrast:
			subject.pve_high_contrast = contrast
			subject.get_tree().call_group("PvEBuffHUD", "pve_update_accessibility", contrast)
	subject.recalculateCursor()

static func addPointOfInterest(subject: Receiver, pos: Vector2, scrollContainer, childToScrollTo, layer):

	for rect in subject.warpPointOcclusionRects:
		if rect.layer >= layer and rect.rect.has_point(pos):
			return

	subject.pointsOfInterest.push_back(pos)
	if scrollContainer != null:
		subject.pointsOfInterestInfo[subject.pointsOfInterest.size() - 1] = [scrollContainer, childToScrollTo]

static func connectToGetRectsSignals(subject: Receiver, receiver: Node, method: String):
	subject.connect("get_rects_menu", Callable(receiver, method))
	subject.connect("get_rects_shop", Callable(receiver, method))
	subject.connect("get_rects_combat", Callable(receiver, method))
	subject.connect("get_rects_title", Callable(receiver, method))

static func connectToWarpCursorSignals(subject: Receiver, receiver: Node, method: String):
	subject.connect("warp_cursor_menu", Callable(receiver, method))
	subject.connect("warp_cursor_shop", Callable(receiver, method))
	subject.connect("warp_cursor_combat", Callable(receiver, method))
	subject.connect("warp_cursor_title", Callable(receiver, method))

static func setConfigValue(subject: Receiver, groupName, propertyName, propertyValue):
	var config = ConfigFile.new()
	var configPath = subject.getSavePath(subject.config_format)
	var err = config.load(configPath)

	config.set_value(groupName, propertyName, propertyValue)
	config.save(configPath)

static func eraseConfigValue(subject: Receiver, groupName, propertyName):
	var config = ConfigFile.new()
	var configPath = subject.getSavePath(subject.config_format)
	var err = config.load(configPath)

	if config.has_section_key(groupName, propertyName):
		config.erase_section_key(groupName, propertyName)
		config.save(configPath)

static func getConfigValue(subject: Receiver, groupName, propertyName, defaultValue):
	var config = ConfigFile.new()
	var configPath = subject.getLoadPath(subject.config_format)
	var err = config.load(configPath)
	if err != OK:
		return defaultValue

	if config.has_section_key(groupName, propertyName):
		return config.get_value(groupName, propertyName, defaultValue)
	else:
		return defaultValue

static func setShowChibis(subject: Receiver, showChibis):
	if not showChibis:
		if subject.getChibiMode():
			subject.PLAYER.setSprite(subject.classResources[subject.curClass], false)
			subject.emit_signal("style_changed")
	else:
		if subject.getChibiMode():
			subject.PLAYER.setSprite(subject.classResources[subject.curClass], true)
			subject.emit_signal("style_changed")

	subject.applySetSkins()
	subject.emit_signal("chibi_setting_changed")

static func setChibiMode(subject: Receiver, _chibiMode):
	if subject.chibiMode[subject.curClass] == _chibiMode: return

	subject.setConfigValue("Options", "Chibi_" + subject.getClassInternalName(), _chibiMode)
	subject.chibiMode[subject.curClass] = _chibiMode
	subject.PLAYER.setSprite(subject.classResources[subject.curClass], subject.chibiMode[subject.curClass])
	subject.emit_signal("style_changed")

static func typeToKeyword(subject: Receiver, _type):
	if _type == subject.EventType.Block:
		return "bl"
	elif _type == subject.EventType.Regeneration:
		return "regen"
	else:
		return subject.eventTypeKeys[_type].to_lower()

static func getDefaultLocale(subject: Receiver):
	if (SteamHelper.is_init() and
		SteamHelper.LOCALE in subject.localeToLanguage):
		return SteamHelper.LOCALE
	else:
		var osLocale = OS.get_locale_language()
		if osLocale in subject.localeToLanguage:
			return osLocale

	return "en"

static func getSkinConfigKey(subject: Receiver, slot: int, charClass, chibi):
	var key = subject.getClassKeys()[charClass]
	if chibi:
		key += "_Chibi_"
	else:
		key += "_Normal_"
	key += subject.SkinSlot.keys()[slot]
	return key

static func getSelectedSkin(subject: Receiver, slot):
	var key = subject.getSkinConfigKey(slot)
	var configuredSkin = subject.getConfigValue("Wardrobe", key, 0)
	if subject.isSkinAvailable(configuredSkin):
		if subject.isSkinUnlocked(slot, configuredSkin):
			return configuredSkin

	return 0

static func getSkinUnlockKey(subject: Receiver, slot: int, charClass, chibi):
	var key = str(charClass) + "_"
	key += str(int(chibi)) + "_"
	key += str(slot)
	return key

static func isSkinUnlocked(subject: Receiver, slot: int, skinId: int):
	var skin = SkinBook.getSkinFromId(subject.curClass, int(subject.getEffectiveChibiMode()), skinId)
	if skin.prices[slot] == 0:
		return true

	var key = subject.getSkinUnlockKey(slot)
	var unlocked = subject.persistent["unlockedSkins"].get(key, [])
	return skinId in unlocked

static func unlockSkin(subject: Receiver, slot: int, skinId: int):
	var key = subject.getSkinUnlockKey(slot)
	var unlocked = subject.persistent["unlockedSkins"].get(key, [])
	unlocked.push_back(skinId)
	subject.persistent["unlockedSkins"][key] = unlocked
	subject.saveGame()
	SteamHelper.unlockAchievement("OutfitUnlocked", true)

static func getItemStatistics(subject: Receiver, statistic: int, descriptor: ItemDescriptor, default):
	if not subject.ITEM_STATISTICS_ENABLED: return null
	var key = subject.getStatisticsKey(statistic)
	var value = subject.persistent[key][descriptor.getIndex()]
	if value == null:
		return default
	return value

static func addRecord(subject: Receiver, statistic: int, descriptor: ItemDescriptor, amount: int):
	if not subject.ITEM_STATISTICS_ENABLED: return

	var runState = subject.getRunState()
	var recordQueue = runState.get("rq", [])
	recordQueue.push_back([descriptor.itemIndex, statistic, amount])
	runState["rq"] = recordQueue

static func showWarning(subject: Receiver, textKey, confirmKey, cancelKey):
	if subject.warning == null:
		subject.warning = load("res://Interface/BoughtNothingWarning.tscn").instantiate()

	if not subject.warning.is_inside_tree():
		subject.warning.open(textKey, confirmKey, cancelKey)

static func quit(subject: Receiver):
	if Expedition.enabled and Expedition.active and not Expedition.save_run():
		Expedition.notice("save_write_failed")
		return
	if subject.quitting: return
	subject.quitting = true
	subject.saveWindowSettings()
	subject._begin_shutdown()
	await AssetStream.drain()
	await subject.get_tree().create_timer(0.12, true, false, true).timeout
	subject.get_tree().call_deferred("quit")

static func checkProcesses_threaded(subject: Receiver):
	if OS.get_name() == "Windows":
		if subject.processThread and subject.processThread.is_active():
			return
		subject.processThread = Thread.new()
		subject.processThread.start(Callable(subject, "checkProcesses"))
