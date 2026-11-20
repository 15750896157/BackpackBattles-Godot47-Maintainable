extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://PvE/UI/Wardrobe/Wardrobe.gd")

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
	if not subject.isOpen or subject.closing: return
	subject.skin_building = true
	subject.hboxContainer.hide()
	subject.skin_revision += 1
	var revision := subject.skin_revision
	var data: Dictionary = subject.model.snapshot()
	var prepared := await AssetStream.prepare(data.paths, "wardrobe-icons")
	if not _current(subject, revision): return
	for child in subject.hboxContainer.get_children():
		subject.hboxContainer.remove_child(child)
		child.queue_free()
	subject.slotButtons.clear()
	subject.selectedSkins = data.selected
	if not prepared or data.skins.is_empty():
		subject.skin_building = false
		AssetStream.release("wardrobe-icons")
		return

	for entry: Dictionary in data.skins:
		await subject.get_tree().process_frame
		if not _current(subject, revision): return
		var skin: CharacterSkin = entry.skin
		var column := VBoxContainer.new()
		column.set("theme_override_constants/separation", 50)
		column.name = str(skin.id)
		subject.hboxContainer.add_child(column)

		var icon = subject.iconScene.instantiate()
		column.add_child(icon)
		icon.setSkin(skin)
		subject.slotButtons.push_back(icon)

		for slot in entry.unlocked.size():
			var slot_button = subject.buttonScene.instantiate()
			column.add_child(slot_button)
			slot_button.init(skin, slot)
			if entry.unlocked[slot]:
				slot_button.setUnlocked()
			subject.slotButtons.push_back(slot_button)

	if _current(subject, revision):
		subject.selectAndPreviewSkinSlots()
		subject.skin_building = false
		subject.hboxContainer.show()

static func _current(subject: Receiver, revision: int) -> bool:
	return is_instance_valid(subject) and subject.isOpen and not subject.closing and subject.skin_revision == revision

static func showPriceTag(subject: Receiver, price: int):
	subject.unlockHint.show()
	subject.priceTag.text = "[center]" + str(price)
	if not subject.model.can_afford(price):
		subject.priceTag.set("theme_override_colors/default_color", Color(1, 0.285156, 0.285156))
	else:
		subject.priceTag.set("theme_override_colors/default_color", Game.SOFTWHITE)
