extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/TitleScreen.gd")

static func _ready(subject: Receiver) -> void :
	if Expedition.enabled:
		subject.call_deferred("_pve_refresh_title")
	subject.get_node("TitleNode/Lobbies").visible = Game.LOBBIES_ENABLED
	subject.get_node("%Quit").visible = not OS.has_feature("web")

	subject.get_node("%RankedBannerHovered").hide()
	subject.get_node("%UnrankedBannerHovered").hide()

	Game.connect("continue_loaded", Callable(subject, "checkSavedRunState"))
	Game.connect("return_to_title", Callable(subject, "checkSavedRunState"))
	Game.connect("runstate_suspended", Callable(subject, "onRunstateSuspended"))
	Game.connect("item_picked_up", Callable(subject, "onItemPickedUp"))
	Game.connect("item_dropped", Callable(subject, "onItemDropped"))

	for classI in subject.classNodes.size():
		var classNode = subject.classNodes[classI]
		if Game.isClassUnlocked(classI):
			classNode.connect("pressed", Callable(subject, "selectClass").bind(classI))
		else:
			classNode.hide()

	subject.add_to_group("Localized")
	Util.localizeFonts(subject.get_node("TitleNode/Concede/ConcedeLabel"))
	subject.updateSocialButtons()

	if Game.LOADOUTS_ENABLED:
		subject.randomClassButton.connect("toggled", Callable(subject, "toggleRandomClass"))

		for i in subject.loadoutButtons.size():
			subject.loadoutButtons[i].connect("toggled", Callable(subject, "onLoadoutButtonToggled").bind(i))
			Util.localizeFonts(subject.loadoutButtons[i])
	else:
		subject.get_node("AboveBlackLayer/Class/Loadouts").queue_free()
		subject.randomClassButton.queue_free()

	subject.loadoutInputBlocker.hide()
	subject.call_deferred("ready_deferred")

static func ready_deferred(subject: Receiver):
	subject.warpPointNodes = Util.getInteractableNodes(subject.get_node("ButtonsNode"))
	Util.walkInteractableNodes(subject.get_node("AboveBlackLayer/Class"), subject.warpPointNodes)
	subject.warpPointNodes.push_back(subject.continueButton)
	subject.warpPointNodes.push_back(subject.rankedButton)
	subject.warpPointNodes.push_back(subject.unrankedButton)
	subject.warpPointNodes.push_back(subject.otherModesButton)
	subject.warpPointNodes.push_back(subject.concedeButton)
	subject.warpPointNodes.push_back(subject.get_node("Node2D/Background/Quit/QuitButton"))
	subject.warpPointNodes.push_back(Game.versionButton)
	Game.connect("warp_cursor_title", Callable(subject, "onCursorWarp"))

static func updateClassNodes(subject: Receiver, curClass, randomCharacter):
	for classI in subject.classNodes.size():
		subject.classNodes[classI].visible = classI in [Game.Classes_Full.Berserker, Game.Classes_Full.Reaper]
		subject.classNodes[classI].disabled = false
	subject.randomClassButton.hide()
	subject.randomClassHint.hide()
	subject.loadoutButtons[2].hide()
	# Random-character outlines are separate artwork and are not used by PvE.
	for border in subject.randomClassNodes: border.hide()
	subject.updateLoadoutLocale(curClass)
	subject.updateLoadoutButtons(false, clampi(Expedition.setup_loadout, 0, 1))
	return

static func updateLoadoutLocale(subject: Receiver, classI):
	if Expedition.db != null:
		var role = "alchemist" if classI == Game.Classes_Full.Reaper else "armorer"
		var rows = Expedition.db.rows("character_loadouts").filter(func(row): return row.character_id == role)
		for i in mini(2, rows.size()): subject.loadoutButtons[i].text = Expedition.t(str(rows[i].name_key))
	return

static func updateSocialButtons(subject: Receiver):
	var showButtons = subject.showSocialButtons()
	var curLocale = TranslationServer.get_locale()
	var isSimplifiedChinese = curLocale == "zh_Hans_CN"
	subject.get_node("ButtonsNode/DiscordButton").visible = showButtons and not isSimplifiedChinese
	subject.get_node("ButtonsNode/YoutubeButton").visible = showButtons and not isSimplifiedChinese
	subject.get_node("ButtonsNode/WikiButton").visible = showButtons
	subject.get_node("WishlistButton").visible = showButtons and not Game.showExclusiveContent()
	subject.get_node("ButtonsNode/QQButton").visible = showButtons
	subject.get_node("ButtonsNode/ChineseItemSearch").visible = showButtons and isSimplifiedChinese

	subject.get_node("Node2D/Background/StaticBody2D2/CollisionPolygon2D").disabled = subject.TRAILER
	subject.get_node("StaticBody2D/CollisionShape2D2").disabled = subject.TRAILER
	subject.get_node("StaticBody2D/CollisionShape2D3").disabled = subject.TRAILER

	subject.get_node("Paper1").visible = subject.TRAILER
	subject.get_node("ItemNode").z_index = 200 if subject.TRAILER else - 2

static func selectClass(subject: Receiver, classI, randomCharacter, visualOnly):
	if Expedition.enabled and classI not in [Game.Classes_Full.Berserker, Game.Classes_Full.Reaper]:
		classI = Game.Classes_Full.Berserker
	if Expedition.enabled and not visualOnly and is_instance_valid(Game.PLAYER) and Game.curClass != classI:
		var epoch = Expedition.view_epoch
		InputBlocker.activate(InputBlocker.Source.Streaming, false)
		var ready = await AssetStream.prepare_actor(classI, Game.getEffectiveChibiMode(), "actor-player", true)
		InputBlocker.deactivate(InputBlocker.Source.Streaming, false)
		if not ready or epoch != Expedition.view_epoch: return
	if randomCharacter == null:
		randomCharacter = Game.randomCharacter

	if Game.draggedItem:
		return

	if subject.selectedClassButton != null:
		subject.selectedClassButton.get_node("Particles").deactivate()
		subject.selectedClassButton.get_node("Glow").hide()

	var classButton = subject.classNodes[classI]
	classButton.get_node("Particles").activate()
	classButton.get_node("Glow").show()
	subject.selectedClassButton = classButton

	if not Game.isClassSelected(classI):
		if visualOnly:
			subject.updateClassNodes(classI, randomCharacter)
			subject.loadoutButtons[Game.getConfiguredLoadout()].set_pressed(true)
		else:
			Game.instanceCharacter(classI)
			subject.updateClassNodes(classI, randomCharacter)

			if Game.LOADOUTS_ENABLED:
				var loadout = Game.getConfiguredLoadout()
				if subject.loadoutButtons[loadout].button_pressed:
					Game.setLoadout(loadout)
				else:
					subject.loadoutButtons[loadout].set_pressed(true)
			else:
				Game.initStartInventory(0)

static func onRandomClassToggled(subject: Receiver, pressed):
	if pressed:
		subject.randomClassHint.show()
		subject.randomClassButton.set_material(subject.rainbowOutlineMaterial)
		subject.randomClassButton.get_node("Particles").activate()
		if subject.randomClassParticles != null:
			subject.randomClassParticles.activate()
		for node in subject.randomClassNodes:
			node.show()
	else:
		subject.randomClassHint.hide()
		subject.randomClassButton.set_material(null)
		subject.randomClassButton.get_node("Particles").deactivate()
		if subject.randomClassParticles != null:
			subject.randomClassParticles.deactivate()
		for node in subject.randomClassNodes:
			node.hide()

static func showTitle(subject: Receiver) -> void :
	if Expedition.enabled:
		subject.itemDropTimer.stop();subject.itemDropTimer2.stop();subject.smokeParticles.emitting=false
		subject.discardAllItems()
		return
	if subject.TRAILER:
		print("trailer")
		var items = []
		var itemList = []
		for itemName in ItemBook.items:
			if ItemBook.items[itemName].version == Game.versionToInt("1.1.0"):
				itemList.push_back(ItemBook.items[itemName])

		itemList.shuffle()
		subject.numTrailerItems = itemList.size()
		for i in subject.numTrailerItems:
			items.push_back(ItemBook.instantiateItem(itemList[i]))
		for i in subject.numTrailerItems:
			Util.callDelayed(subject, "dropItem", 3 + i * 0.02, [items[i]])
		subject.itemsScheduled = subject.numTrailerItems
	else:
		subject.itemDropTimer.start(1)

		subject.smokeParticles.emitting = true

static func dropItem(subject: Receiver, _item):
	if Expedition.enabled: return
	subject.itemsScheduled = max(0, subject.itemsScheduled - 1)
	if (Game.state != Game.State.Title or
		(Game.sceneAnimation.current_animation != "" and
		Game.sceneAnimation.current_animation != "StartOnTitle")):
		return

	var item = _item
	if not item:
		var descriptor = ItemBook.getRandomItemWithRarityOdds(subject.rarityOdds)

		var paths: Array = []
		for child in subject.itemNode.get_children():
			if child is Item: paths.append(child.descriptor.scene_path)
		paths.append(descriptor.scene_path)
		paths.append("res://Items/Shadow.tscn")
		paths.append("res://Interface/DustParticles.tscn")
		if not await AssetStream.prepare(paths, "title-decoration"): return
		item = await AssetStream.instantiate_path(descriptor.scene_path, "title-decoration")
		if item == null: return
		item.descriptor = descriptor
		if Game.state != Game.State.Title or subject.itemNode.get_child_count() >= subject.MAX_ITEMS:
			item.free()
			return

	item.ownerType = Item.Owner.Title
	subject.itemNode.add_child(item)
	item.initTitle()

	if subject.TRAILER:

		item.position = Vector2(subject.xPos, - 900)
		subject.xPos += Util.rng.randf_range(200, 300)
		if subject.xPos > 1400:
			subject.xPos = 400
	else:
		item.position = Vector2(subject.xPos, - 200)
		subject.xPos += Util.rng.randf_range(100, 300)

		if subject.xPos > 1600:
			subject.xPos -= 400

	subject.positionItem(item)

	if Util.rng.randf() < 0.1:
		item.impactSoundVolume = - 5
	else:
		item.impactSoundVolume = - 12

	Util.callDelayed(subject, "applyImpulse", 0.01, [item])

static func applyImpulse(subject: Receiver, item):
	var offset_vector = Vector2(Util.rng.randf_range(-subject.offset, subject.offset),
		Util.rng.randf_range(-subject.offset, subject.offset))
	var impulse_vector = Vector2(Util.rng.randf_range(-subject.impulse, subject.impulse),
		Util.rng.randf_range(-subject.impulse, subject.impulse))
	item.apply_impulse(impulse_vector, offset_vector)

static func _pve_refresh_title(subject: Receiver):
	while not Expedition.initialized:
		await subject.get_tree().process_frame
	subject.get_node("TitleNode/Lobbies").hide()
	subject.otherModesButton.hide()
	subject.randomClassButton.hide()
	subject.randomClassHint.hide()
	subject.loadoutButtons[2].hide()
	Game.randomCharacter = false
	subject.updateClassNodes(Game.curClass, false)
	subject.selectClass(Game.curClass, false, true)
	subject.updateLocale()
	subject._pve_refresh_continue()

static func _pve_refresh_continue(subject: Receiver):
	if Expedition.flow == null: return
	var saved = Expedition.flow.saves.load_save("run")
	var valid = saved.get("ok", false) and Expedition.flow.saves.validate_run(saved.get("data", {}), Expedition.db).get("ok", false)
	if valid and str(saved.data.get("last_safe_state", saved.data.get("state", ""))) == "RUN_RESULT": valid = false
	# The inherited Hide animation also hides Continue and moves/fades its banner.
	# PvE owns these two controls independently; stop the old timeline before refresh.
	subject.concedeAnimation.stop()
	subject.concedeAnimation.get_parent().hide()
	# Continue belongs to the chosen standard/tutorial entrance, never a third banner.
	subject.continueNode.visible = false
	subject.continueNode.position = Vector2(560, 120)
	subject.continueNode.modulate = Color.WHITE
	subject.continueButton.disabled = true
	subject.customRulesIcon.hide()
	subject.rankedButton.disabled = false
	subject.unrankedButton.disabled = false
	if valid:
		subject.get_node("%LastRunRound").text = str((int(saved.data.act) - 1) * 5 + int(saved.data.step))
		subject.get_node("%LastRunWins").text = str(saved.data.get("logs", []).filter(func(entry): return int(entry.get("winner", 1)) == 0).size())
		subject.get_node("%LastRunTries").text = str(int(ceil(float(saved.data.health))))
	subject.updateClassNodes(Game.curClass, false)

static func updateLocale(subject: Receiver):
	if Expedition.initialized:
		for pair in [["RankedLabel", "standard"], ["UnrankedLabel", "tutorial"]]:
			var banner_label = subject.get_node("TitleNode/" + str(pair[0]))
			banner_label.translationKey = ""
			banner_label.text = Expedition.t("difficulty." + str(pair[1]) + ".name") + "\n" + Expedition.t("ui.begin_expedition")
			banner_label.shrinkIfTooBig(banner_label.text)
		subject.updateLoadoutLocale(Game.curClass)
	return

static func otherModesUIPressed(subject: Receiver):
	if not Game.draggedItem and not Game.runStarted:

		if Game.otherModesUI == null:
			Game.otherModesUI = load("res://Interface/Lobbies/OtherModesUI.tscn").instantiate()
			Game.otherModesUI.connect("cancel", Callable(subject, "onOtherModeClosed"))

		Game.otherModesUI.open()
		subject.disableButtons(true)

static func onCursorWarp(subject: Receiver):
	if is_instance_valid(Game.wardrobe) and Game.wardrobe.isOpen:
		for button in subject.classButtonsNode.get_children():
			if not button.disabled and button.visible:
				Game.addControlOfInterest(button)

		for slotButton in Game.wardrobe.getSlotButtons():
			Game.addControlOfInterest(slotButton)

		if Game.wardrobe.chibiButton.visible:
			Game.addControlOfInterest(Game.wardrobe.chibiButton, Vector2( - 30, 0))

		Game.addPointOfInterest(Vector2(850, 700))
	else:
		for button in subject.warpPointNodes:
			if not button.disabled and button.visible:
				Game.addControlOfInterest(button)
