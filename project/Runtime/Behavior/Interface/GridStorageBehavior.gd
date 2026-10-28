extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/GridStorage.gd")

static func _ready(subject: Receiver):
	Game.gridStorage = subject
	if subject.visible:
		Game.STORAGEBOX.connect("item_added", Callable(subject, "onItemAddedToStorage"))
		Game.STORAGEBOX.connect("item_removed", Callable(subject, "onItemRemovedFromStorage"))
		Game.STORAGEBOX.connect("storage_cleared", Callable(subject, "onStorageCleared"))
		Game.connect("edit_mode_changed", Callable(subject, "onEditModeChanged"))
		Game.connect("return_to_title", Callable(subject, "onReturningToTitle"))
		Game.connect("shop_opened", Callable(subject, "onShopEntered"))
		Game.undoStack.connect("state_changed", Callable(subject, "onUndoStateChanged"))
		subject.scrollContainer.connect("zoomed", Callable(subject, "onZoomed"))
		if not Expedition.enabled: ObjectPool.prepare(subject.entryScene, 2)
	subject.hide()

static func actuallyRebuild(subject: Receiver):
	subject.rebuildQueued = false
	subject.clear()

	if not subject.visible: return

	var itemDict = Game.STORAGEBOX.getItemsAndGemsByDescriptor()
	var scores = {}
	for descriptor in itemDict:
		scores[descriptor] = subject.getScore(descriptor)
	var sorted = Util.sortDict(scores)

	var margin = subject.gridContainer.get("theme_override_constants/h_separation")
	var usableWidth = 420 - (subject.gridContainer.columns - 1) * margin
	var widthPerEntry = usableWidth / subject.gridContainer.columns

	for descriptor in sorted:
		var entry = ObjectPool.instantiate(subject.entryScene)
		entry.custom_minimum_size.x = widthPerEntry
		entry.custom_minimum_size.y = entry.custom_minimum_size.x

		subject.gridContainer.add_child(entry)
		entry.setItems(itemDict[descriptor], descriptor in subject.newItems,
			subject.itemScale[subject.gridContainer.columns])
		subject.descriptorToEntry[descriptor] = entry

	subject.newItems.clear()

static func getScore(subject: Receiver, descriptor) -> float:
	var score = 0
	if descriptor.isBag():
		score += 1000000

	score += descriptor.getRarity() * 10000
	score += descriptor.getPrice()
	score += descriptor.itemIndex * 0.0001

	if descriptor.isGem():
		score -= 1000000

	return score
