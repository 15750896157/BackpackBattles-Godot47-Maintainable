extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/GridStorageEntry.gd")

static func setItems(subject: Receiver, itemList: Array, wasJustAdded: bool, itemMaxScale):
	subject.physicalItems = itemList
	var descriptor = itemList[0].descriptor
	subject.item = descriptor.instantiate_pooled()
	subject.item.ownerType = subject.item.Owner.GridStorage
	subject.add_child(subject.item)
	subject.item.initGridStorageIcon()
	subject.item.scaleToFit(subject.custom_minimum_size - Vector2(2, 2), itemMaxScale)

	subject.item.position = subject.custom_minimum_size * 0.5
	subject.item.position += subject.item.getSpriteOffset() * 2.0

	if itemList.size() == 1:
		subject.multiplicityLabel.hide()
	else:
		subject.multiplicityLabel.show()
		subject.multiplicityLabel.text = str(itemList.size())
		subject.labelNode.position = subject.labelPos * (subject.custom_minimum_size / subject.defaultSize)

	subject.panel.modulate = Game.rarityColors[descriptor.getRarity()].lightened(0.5)

	subject.setEditable()
	if Game.inventoryEditMode == Game.InventoryEditMode.BagLayer:
		if not descriptor.isBag():
			subject.setNotEditable()
	elif Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer:
		if descriptor.isBag():
			subject.setNotEditable()

	if wasJustAdded:
		subject.item.popIn(true, 1.2)

	if subject.item.isA(ItemBook.magicRingDescriptor) or subject.item.isA(ItemBook.superiorRingDescriptor):
		subject.item.copyFrom(subject.physicalItems[ - 1])

static func _gui_input(subject: Receiver, event):
	if subject.pickingEnabled and Util.isClickEvent(event):
		Game.cancelSwitch()
		var itemToPick = subject.physicalItems.pop_back()
		itemToPick.global_position = subject.get_global_mouse_position()
		itemToPick.show()
		itemToPick.enablePicking()

		itemToPick.pickup()
		Game.gridStorage.rebuild()
