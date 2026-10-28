extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Shop.gd")

static func _ready(subject: Receiver) -> void :
	Game.connect("shop_opened", Callable(subject, "openShop"))
	Game.connect("switch_to_shop", Callable(subject, "enteringShop"))
	Game.connect("shop_closed", Callable(subject, "closeShop"))
	Game.connect("returned_to_title", Callable(subject, "clear"))
	Game.connect("run_over", Callable(subject, "resetRerollCounter"))
	Game.connect("item_picked_up", Callable(subject, "onItemPickedUp"))
	Game.connect("item_dropped", Callable(subject, "onItemDropped"))
	subject.bannerTimer.connect("timeout", Callable(subject, "onBannerTimerTimeout"))
	subject.resetRerollCounter()

	if Util.isChristmas():
		var snowglobe = load("res://Assets/Decoration/SnowGlobe.tscn").instantiate()
		subject.add_child(snowglobe)

static func stashItems(subject: Receiver):
	for i in subject.slots.size():
		if subject.slots[i].reserved:
			subject.stashedItems.push_back(ItemBook.getItemIndex(subject.slots[i].item))
			subject.stashedSales.push_back(subject.slots[i].onSale)

			var persistentData = subject.slots[i].item.getData()
			subject.stashedItemData.push_back(persistentData)

		else:
			subject.stashedItems.push_back( - 1)
			subject.stashedSales.push_back( - 1)
			subject.stashedItemData.push_back(null)

		subject.slots[i].resetFull()

static func unstashItems(subject: Receiver):
	for i in subject.stashedItems.size():
		if subject.stashedItems[i] != - 1:
			var saleMode = Game.SaleMode.Sale if subject.stashedSales[i] else Game.SaleMode.NoSale
			subject.slots[i].setItem(ItemBook.instantiateItemFromIndex(subject.stashedItems[i]), saleMode)
			subject.slots[i].setReserved(true)
			if subject.stashedItemData[i] != null:
				subject.slots[i].item.setData(subject.stashedItemData[i])

	subject.stashedItems.clear()
	subject.stashedSales.clear()
	subject.stashedItemData.clear()

static func showSubclassShop(subject: Receiver):
	if not subject.chooseOneShop:
		subject.chooseOneShop = true

		subject.showChooseOneSign()

		subject.stashItems()

		var subclassItems = ItemBook.getSubclassItemDescr(Game.curClass)

		subject.slots[0].setItem(ItemBook.instantiateItem(subclassItems[0]), Game.SaleMode.Roll)
		subject.slots[4].setItem(ItemBook.instantiateItem(subclassItems[1]), Game.SaleMode.Roll)
		subject.slots[2].setItem(ItemBook.instantiateItem(subclassItems[2]), Game.SaleMode.Roll)

		if subclassItems.size() == 5:
			subject.slots[3].setItem(ItemBook.instantiateItem(subclassItems[3]), Game.SaleMode.Roll)
			subject.slots[1].setItem(ItemBook.instantiateItem(subclassItems[4]), Game.SaleMode.Roll)

		for slot in subject.slots:
			if slot.item != null:
				Game.incrementItemStatistic(Game.ItemStatistic.SeenInShop, slot.item.descriptor)

		Sound.playSound(subject.skillRoundSound, - 4, 1.1)

		Game.saveRunState()
		subject.emit_signal("shop_refreshed")

static func showSkillShop(subject: Receiver):
	if not subject.chooseOneShop:
		subject.chooseOneShop = true

		subject.showChooseOneSign()
		subject.stashItems()

		var skills = ItemBook.getRandomSkills()

		subject.slots[0].setItem(ItemBook.instantiateItem(skills[0]), Game.SaleMode.Roll)
		subject.slots[4].setItem(ItemBook.instantiateItem(skills[1]), Game.SaleMode.Roll)
		subject.slots[2].setItem(ItemBook.instantiateItem(skills[2]), Game.SaleMode.Roll)
		if Game.curRound == Game.SKILL_ROUND1:
			subject.slots[1].setItem(ItemBook.instantiateItem(ItemBook.justStatsDescriptor), Game.SaleMode.Roll)
		else:
			subject.slots[1].setItem(ItemBook.instantiateItem(ItemBook.moreStatsDescriptor), Game.SaleMode.Roll)

		var unidentifiedSkill = ItemBook.instantiateItem(ItemBook.unidentifiedSkillDescriptor)
		subject.slots[3].setItem(unidentifiedSkill, Game.SaleMode.Roll)

		for slot in subject.slots:
			if slot.item != null:
				Game.incrementItemStatistic(Game.ItemStatistic.SeenInShop, slot.item.descriptor)

		Sound.playSound(subject.skillRoundSound)

		Game.saveRunState()
		subject.emit_signal("shop_refreshed")

static func getUniqueSlots(subject: Receiver) -> Array:
	var uniqueSlots = []
	var uniquesAllowed = ItemBook.getMaxUniques() - ItemBook.getNumUniques()

	if uniquesAllowed > 0:
		var uniqueChance = subject.getUniqueChance()
		subject.uniqueAcc += uniqueChance
		var nonReserved = subject.getNonReservedSlotIndices()

		var uniques: int = Util.flipRound(uniqueChance)
		if uniques == 0 and subject.uniqueAcc > 1.2:
			uniques = 1

		uniques = min(uniques, min(nonReserved.size(), uniquesAllowed))

		for i in uniques:
			var slot = nonReserved[0]
			nonReserved.erase(slot)
			subject.uniqueAcc = 0.0
			uniqueChance -= 1.0
			uniqueSlots.push_back(slot)
			uniquesAllowed -= 1

	return uniqueSlots

static func getUniqueChance(subject: Receiver):
	var uniqueChance = subject.UNIQUE_CHANCES[min(Game.curRound - 1, subject.UNIQUE_CHANCES.size() - 1)]

	if ItemBook.isItemInInventory(subject.megaCloverDescriptor):
		uniqueChance += subject.megaCloverDescriptor.getP("uniques") / 100.0

	var platCards = ItemBook.countItemsInInventoryOfType(ItemBook.platinCardDescriptor)
	uniqueChance += platCards * ItemBook.platinCardDescriptor.getP("uniques") / 100.0

	var stars = ItemBook.countItemsInInventoryOfType(ItemBook.starOfCourageDescriptor)
	uniqueChance += stars * ItemBook.starOfCourageDescriptor.getP("uniques") / 100.0

	if ItemBook.isItemInInventory(ItemBook.uniquelyUniqueDescriptor):
		uniqueChance += ItemBook.uniquelyUniqueDescriptor.getP("uniques") / 100.0

	if ItemBook.isItemInInventory(ItemBook.fedoraDescriptor):
		uniqueChance += ItemBook.fedoraDescriptor.getP("uniques") / 100.0

	uniqueChance += CustomRules.getBonusUniqueChance() / 100.0

	return uniqueChance

static func getHighRollBuckets(subject: Receiver):
	var highRollBuckets = [0, 0, 0, 0, 0]

	var nonReservedSlots = subject.getNonReservedSlotIndices()
	if not nonReservedSlots.is_empty():

		for item in ItemBook.getItemsInInventoryOfType(ItemBook.customerCardDescriptor):
			var slotIndex = Util.pickRandomElement(nonReservedSlots)
			highRollBuckets[slotIndex] += 1
			subject.spawnHighRollParticles(slotIndex)
			item.activate()
	return highRollBuckets

static func rollSale(subject: Receiver, slot) -> bool:

	if not subject.saleSlots.is_empty():
		if slot.index in subject.saleSlots:
			subject.saleSlots.erase(slot.index)
			return true

	var isSale = false

	var saleChance = subject.getSaleChance(slot.item)
	if CustomRules.isRuleDefault(CustomRules.Rules.SalesChance):
		saleChance *= slot.item.getSalesMultiplier()

	if Util.flip(saleChance):
		isSale = true
	else:
		subject.saleAcc += saleChance
		if subject.saleAcc > 1.3:
			isSale = true

	if isSale:
		subject.saleAcc = 0.0

	return isSale
