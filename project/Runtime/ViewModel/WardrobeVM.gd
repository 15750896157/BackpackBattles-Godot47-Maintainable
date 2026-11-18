extends ViewModel
## Projects wardrobe choices from the original class, style and unlock rules.
var _game
var _skin_book

func _init(game, skin_book) -> void:
	_game = game
	_skin_book = skin_book

func snapshot() -> Dictionary:
	var class_id: int = _game.curClass
	var style := int(_game.getEffectiveChibiMode())
	var paths: Array[String] = []
	var entries: Array[Dictionary] = []
	var selected: Array[int] = []
	if not _game.isClassUnlocked():
		return {"paths": paths, "skins": entries, "selected": selected}
	var skins: Array = _skin_book.getSkinsForClass(class_id, style).duplicate()
	skins.sort_custom(Callable(_skin_book.OrderSorter, "sort"))
	var slots: int = _game.SkinSlot.size()
	for slot in slots:
		selected.append(_game.getSelectedSkin(slot))
	for skin: CharacterSkin in skins:
		# Recovered catalogues can describe skins whose original assets are absent.
		if not ResourceLoader.exists(skin.scene_path, "PackedScene"):
			continue
		paths.append_array([skin.preview_icon_path(), skin.preview_hovered_path(), skin.scene_path])
		var unlocked: Array[bool] = []
		for slot in slots:
			unlocked.append(is_unlocked(slot, skin.id))
		entries.append({"skin": skin, "unlocked": unlocked})
	return {"paths": paths, "skins": entries, "selected": selected}

func is_unlocked(slot: int, skin_id: int) -> bool:
	return _game.isSkinUnlocked(slot, skin_id)

func select(slot: int, skin_id: int) -> bool:
	if not is_unlocked(slot, skin_id):
		return false
	_game.selectSkin(slot, skin_id)
	changed.emit()
	return true

func can_afford(price: int) -> bool:
	return _game.getTrophies() >= price
