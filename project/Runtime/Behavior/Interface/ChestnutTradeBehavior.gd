extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/ChestnutTrade.gd")

static func _ready(subject: Receiver):
	Game.connect("return_to_title", Callable(subject, "onReturnToTitle"))
	Game.connect("shop_opened", Callable(subject, "onShopOpened"))
	Game.connect("shop_closed", Callable(subject, "onShopClosed"))
	Game.connect("warp_cursor_shop", Callable(subject, "onCursorWarp"))

static func startTrade(subject: Receiver, bonusValue: int):
	var tradeWasActive = subject.isTradeActive()

	if subject.wantItem != null:
		subject.clearItem(subject.wantItem, false)
		subject.wantItem = null

	if subject.giveItem != null:
		subject.clearItem(subject.giveItem, false)
		subject.giveItem = null

	subject.active = false

	var wantCandidates = []
	for item in ItemBook.getOwnedItems():
		if (item.getRarity() != Item.Rarity.Unique and
			not item.isBag() and
			not item.descriptor in subject.tradeExcludeItems):
			wantCandidates.push_back(item.descriptor)

	if wantCandidates.is_empty():
		return

	wantCandidates = Util.filterDuplicates(wantCandidates)
	wantCandidates.shuffle()

	var itemPool = ItemPool.new()
	var filters = ItemBook.Filter.Gems + ItemBook.Filter.Amulets + ItemBook.Filter.Crafted
	for descriptor in ItemBook.items.values():
		if ItemBook.canBeGenerated(descriptor, filters):
			itemPool.addItem(descriptor)
	itemPool.sortItems()

	for wantDescriptor in wantCandidates:
		var giveCandidates = []
		var price = wantDescriptor.getPrice() + bonusValue

		for descriptor in itemPool.pool:
			if descriptor != wantDescriptor:
				var priceDif = descriptor.price - price
				if priceDif == 2 or priceDif == 1:
					giveCandidates.push_back(descriptor)

		if not giveCandidates.is_empty():
			subject.active = true

			if tradeWasActive:
				subject.animation.play("NewTrade")
			else:
				subject.animation.play("ShowTrade")
				for ani in subject.idleAnimations:
					ani.play("Idle")

			var giveDescriptor = giveCandidates.pick_random()

			subject.wantItem = subject.initItem(wantDescriptor, subject.wantItemNode)
			subject.giveItem = subject.initItem(giveDescriptor, subject.giveItemNode)

			if ItemBook.isRing(subject.giveItem):
				subject.giveItem.randEffects(false)

			Game.saveRunState()

			return

	if tradeWasActive:
		subject.endTrade()

	print("cannot find give item.")

static func initItem(subject: Receiver, descriptor, parent):
	var item = descriptor.instantiate_pooled()
	item.ownerType = item.Owner.BuildViewerIcon
	parent.add_child(item)
	item.initBuildViewerIcon()

	item.scaleToFit_local(Vector2(90, 100), 0.7)
	item.position = item.getSpriteOffset_local()
	item.popIn()
	var hoverArea = parent.get_node("HoverArea")
	hoverArea.connect("mouse_entered", Callable(subject, "onItemHovered").bind(item))
	hoverArea.connect("mouse_exited", Callable(subject, "onItemHoverEnd").bind(item))
	hoverArea.show()
	return item

static func clearItem(subject: Receiver, item, instant: bool):
	item.hoverEnd()
	var parent = item.get_parent()
	var hoverArea = parent.get_node("HoverArea")
	hoverArea.disconnect("mouse_entered", Callable(subject, "onItemHovered"))
	hoverArea.disconnect("mouse_exited", Callable(subject, "onItemHoverEnd"))
	hoverArea.hide()
	if instant:
		item.discard()
	else:
		item.disappear()

static func updateColor(subject: Receiver, item):
	subject.modulate = Color.WHITE
	if item == null:
		subject.bubble.self_modulate = subject.darkColor
	elif not subject.isTradable(item):
		if Game.SELLBOX.hovered:
			subject.modulate = Color(0.78, 0.78, 0.96)
			subject.bubble.self_modulate = subject.darkColor
		else:
			subject.bubble.self_modulate = subject.darkColor

	else:
		if Game.SELLBOX.hovered:
			subject.bubble.self_modulate = Color(1.05, 1.05, 0.9)
		else:
			subject.bubble.self_modulate = Color(1, 1, 1)

static func setTrade(subject: Receiver, wantItemIndex, giveItemIndex, giveData):
	subject.active = true
	subject.animation.play("ShowTrade")
	for ani in subject.idleAnimations:
		ani.play("Idle")

	subject.wantItem = subject.initItem(ItemBook.getDescriptorFromIndex(wantItemIndex), subject.wantItemNode)
	subject.giveItem = subject.initItem(ItemBook.getDescriptorFromIndex(giveItemIndex), subject.giveItemNode)

	if giveData != null:
		subject.giveItem.setData(giveData)

static func reset(subject: Receiver):
	subject.animation.play("RESET")
	for ani in subject.idleAnimations:
		ani.stop()

	if subject.wantItem != null:
		subject.clearItem(subject.wantItem, true)
		subject.wantItem = null

	if subject.giveItem != null:
		subject.clearItem(subject.giveItem, true)
		subject.giveItem = null
