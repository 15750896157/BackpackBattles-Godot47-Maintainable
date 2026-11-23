extends Node2D
## Legacy query adapter. Opening the catalog uses the lightweight local UI.
signal open_library
signal items_initialized
const SPOTLIGHT_POS = Vector2(985, 555)
const MAX_PROTOTYPES = 4
var isOpen: bool = false
var items: Dictionary = {}
var spotlight
func init():
	items_initialized.emit()
func open():
	open_library.emit()
	Expedition.show_codex()
func closed():
	isOpen = false
func getInstance(descriptor):
	if items.has(descriptor): return items[descriptor]
	if items.size() >= MAX_PROTOTYPES:
		var oldest = items.keys()[0]
		items[oldest].discard()
		items.erase(oldest)
	var item = descriptor.instantiate()
	item.ownerType = Item.Owner.ItemLibrary
	add_child(item)
	item.hide()
	item.process_mode = Node.PROCESS_MODE_DISABLED
	items[descriptor] = item
	return item
func clear():
	for item in items.values():
		if is_instance_valid(item): item.discard()
	items.clear()
	spotlight = null
func updateSearchDescriptions():
	for descriptor in ItemBook.items.values(): descriptor.searchDescription = (descriptor.getTranslatedName() + " " + descriptor.getDescription()).to_lower()
func hideRecordIcons():
	pass
func filterChanged():
	pass
func setSpotlightItem(item):
	spotlight = item
func setSpotlightDescriptor(descriptor):
	spotlight = getInstance(descriptor)
func getSpotlightItem():
	return spotlight
