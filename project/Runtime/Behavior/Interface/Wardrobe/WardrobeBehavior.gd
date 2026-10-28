extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Wardrobe/Wardrobe.gd")

static func _ready(subject: Receiver):
	Game.connect("character_changed", Callable(subject, "onCharacterSelected"))
	Game.connect("style_changed", Callable(subject, "onSwitchStyle"))
	Game.connect("input_changed", Callable(subject, "updateHint"))
	# Controls under the wardrobe scroll area receive input before the title button.
	# Keep a visible close action inside the menu itself.
	subject.closeButton = Button.new()
	subject.closeButton.text = Util.tra("BUTTON_CloseWardrobe")
	subject.closeButton.theme = Expedition.ui_theme
	subject.closeButton.name = "CloseButton"
	subject.closeButton.position = Vector2(1770, 328)
	subject.closeButton.size = Vector2(120, 44)
	subject.add_child(subject.closeButton)
	subject.closeButton.pressed.connect(subject.close)
	Util.localizeFonts(subject.closeButton)

	subject.playerZ = Game.PLAYER.spriteNode.z_index

static func open(subject: Receiver):
	subject.isOpen = true
	Game.UINode.get_node("WardrobePlaceholder").add_sibling(subject)
	subject.animation.play("Open")
	Sound.playSound(subject.openSound, - 6)
	Sound.setMuffledSound(true)
	subject.initSkins()
	Game.PLAYER.spriteNode.z_index = subject.playerZ + 20
	Game.titleScreen.classButtonsNode.z_index = 2

	subject.trophyCounter.updateValue()
	Util.updateLocaleInSubtree(subject)

static func initSkins(subject: Receiver):
	subject.skin_building = true
	subject.hboxContainer.hide()
	subject.skin_revision += 1
	var revision = subject.skin_revision
	var paths: Array = []
	for skin in SkinBook.getSkinsForClass(Game.curClass, int(Game.getEffectiveChibiMode())):
		paths.append(skin.icon_path)
		paths.append(skin.hovered_path)
		paths.append(skin.scene_path)
	if not await AssetStream.prepare(paths, "wardrobe-icons"): return
	if not is_instance_valid(subject) or not subject.isOpen or subject.skin_revision != revision: return
	for child in subject.hboxContainer.get_children():
		child.name = "deleting"
		child.queue_free()

	subject.slotButtons.clear()

	var skins = SkinBook.getSkinsForClass(Game.curClass,
		int(Game.getEffectiveChibiMode())).duplicate()

	if not Game.isClassUnlocked(): return
	if skins.is_empty(): return

	skins.sort_custom(Callable(SkinBook.OrderSorter, "sort"))

	subject.selectedSkins.clear()
	for slot in Game.SkinSlot:
		var skinId = Game.getSelectedSkin(Game.SkinSlot[slot])
		subject.selectedSkins.push_back(skinId)

	for skin in skins:
		await subject.get_tree().process_frame
		if not is_instance_valid(subject) or not subject.isOpen or subject.skin_revision != revision: return
		var vbox = VBoxContainer.new()
		vbox.set("theme_override_constants/separation", 50)
		subject.hboxContainer.add_child(vbox)
		vbox.name = str(skin.id)

		var icon = subject.iconScene.instantiate()
		vbox.add_child(icon)
		icon.setSkin(skin)
		subject.slotButtons.push_back(icon)

		for slot in Game.SkinSlot.size():
			var slotButton = subject.buttonScene.instantiate()
			vbox.add_child(slotButton)
			slotButton.init(skin, slot)
			if Game.isSkinUnlocked(slot, skin.id):
				slotButton.setUnlocked()
			subject.slotButtons.push_back(slotButton)

	if subject.isOpen and subject.skin_revision == revision:
		subject.selectAndPreviewSkinSlots()
		subject.skin_building = false
		subject.hboxContainer.show()

static func showPriceTag(subject: Receiver, price: int):
	subject.unlockHint.show()
	subject.priceTag.text = "[center]" + str(price)
	if Game.getTrophies() < price:
		subject.priceTag.set("theme_override_colors/default_color", Color(1, 0.285156, 0.285156))
	else:
		subject.priceTag.set("theme_override_colors/default_color", Game.SOFTWHITE)
