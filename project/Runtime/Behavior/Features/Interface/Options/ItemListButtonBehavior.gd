extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Options/ItemListButton.gd")

static func addItem(subject: Receiver, itemText, itemIcon):
	var index = subject.rawItems.size()
	subject.icons[index] = itemIcon
	subject.rawItems.push_back(itemText)
	subject.itemList.add_item(Util.tr(itemText), itemIcon)
	subject.widen(itemText, itemIcon)

static func showItemList(subject: Receiver):
	subject.openFrame = Util.getFrameCounter_process()
	subject.itemList.show()
	subject.itemList.grab_focus()
	subject.set_process(true)
	Game.onHoverInteractable(subject)
	Util.callNextFrame(subject, "calcHoverRect")
	subject.emit_signal("list_opened")
	Game.itemListOpened = true

static func calcHoverRect(subject: Receiver):
	if not subject.is_inside_tree():
		print(subject.name, " not inside tree")
		return
	subject.hoverRect.position = subject.global_position - subject.TOPLEFT_MARGIN
	var maxSize = Vector2(max(subject.itemList.size.x, subject.size.x), subject.itemList.size.y)
	subject.hoverRect.size = maxSize + subject.TOPLEFT_MARGIN + subject.BOTTOMRIGHT_MARGIN

static func onItemSelected(subject: Receiver, index: int):
	subject.emit_signal("item_selected", index, subject.itemList.get_item_text(index))
	subject.updateText(index)
	subject.hideItemList()
	subject.focusLostFrame = Util.getFrameCounter_process()
	Game.onClickButton()
	Game.disableTooltipsFor(12)
	Game.disableHoverResponsesFor(12)

static func onGetRects(subject: Receiver):
	if subject.itemList.visible:
		var size = Vector2(max(subject.itemList.size.x, subject.size.x), subject.itemList.size.y)
		Game.addOcclusion(subject.global_position, size, 1)
