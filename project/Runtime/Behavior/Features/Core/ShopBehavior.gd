extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Shop.gd")

static func resetRerollCounter(subject: Receiver):
	subject.rerollsThisRun = 0
	subject.rollsThisRun = 0
	subject.saleAcc = 0.0
	subject.uniqueAcc = 0.0

	subject.encounteredRoll.clear()
	subject.rerolledRoll.clear()
	for item in ItemBook.getNumItems():
		subject.encounteredRoll.push_back(ItemBook.NOT_ENCOUNTERED)
		subject.rerolledRoll.push_back(ItemBook.NOT_ENCOUNTERED)

static func getRerollProgress(subject: Receiver) -> float:
	if subject.rerollsThisRound <= subject.REROLL_THRESHOLD1:
		return subject.rerollsThisRound / float(subject.REROLL_THRESHOLD1)
	elif subject.rerollsThisRound <= subject.REROLL_THRESHOLD2:
		return (subject.rerollsThisRound - subject.REROLL_THRESHOLD1) / float(subject.REROLL_THRESHOLD2 - subject.REROLL_THRESHOLD1)
	else:
		return 1.0

static func showChooseOneSign(subject: Receiver):
	if not Game.SKILLS_ENABLED: return

	subject.shopSignLabel.hide()
	subject.chooseOneLabel.show()
	if Game.curRound == Game.SUBCLASS_ROUND:
		subject.chooseOneLabel.translationKey = "UI_ChooseSubclass"
	else:
		subject.chooseOneLabel.translationKey = "UI_ChooseSkill"
	subject.chooseOneLabel.updateLocale()

	subject.rarityChart.disappear()
	subject.bannerTimer.start(subject.bannerHighlightInterval)

static func getSaleChance(subject: Receiver, item):
	var chance = subject.SALE_CHANCE

	subject.bonusSaleChance = 0
	subject.emit_signal("roll_sale", item)

	chance += subject.bonusSaleChance

	if CustomRules.customRulesActive:
		chance += CustomRules.getRuleValue(CustomRules.Rules.SalesChance) / 100.0

	return chance

static func getFreeSlot(subject: Receiver, excludedSlots) -> int:
	var nonReservedSlots = subject.getNonReservedSlotIndices()
	nonReservedSlots = Util.subtractArr(nonReservedSlots, excludedSlots)
	if not nonReservedSlots.is_empty():
		return nonReservedSlots[0]
	else:
		return - 1

static func checkSalesAch(subject: Receiver):
	var numOnSale = 0
	for slot in subject.slots:
		if slot.onSale:
			numOnSale += 1
	if numOnSale == 5:
		SteamHelper.unlockAchievement("Sale")

static func clear(subject: Receiver):
	for slot in subject.slots:
		slot.resetFull()
	subject.stashedItems.clear()
	subject.stashedSales.clear()
	subject.stashedItemData.clear()
	subject.chooseOneShop = false
	subject.chooseOneLabel.hide()
	subject.shopSignLabel.show()
	subject.reservedItemsCounter.clear()

static func setItem(subject: Receiver, slotIndex, item):

	var saleMode = Game.SaleMode.Roll
	if subject.chooseOneShop:
		saleMode = Game.SaleMode.NoSale
	subject.slots[slotIndex].setItem(item)
	item.popIn()

static func setOnSale(subject: Receiver, slotIndex, onSale):
	if onSale:
		subject.slots[slotIndex].setSaleMode(Game.SaleMode.Sale)
	else:
		subject.slots[slotIndex].setSaleMode(Game.SaleMode.NoSale)
	subject.slots[slotIndex].calcPrice()

static func getItems(subject: Receiver):
	var items = []
	for i in subject.slots.size():
		if subject.slots[i].bought:
			items.push_back(null)
		else:
			items.push_back(subject.slots[i].item)
	return items

static func getReservedItemsNoNull(subject: Receiver):
	var items = []
	for i in subject.slots.size():
		if subject.slots[i].reserved:
			items.push_back(subject.slots[i].item)
	return items

static func spawnHighRollParticles(subject: Receiver, slotIndex):
	var particles = ObjectPool.instantiate(subject.highRollParticlesScene)
	subject.add_child(particles)
	particles.global_position = subject.slots[slotIndex].global_position
	particles.restart()
	ObjectPool.returnAfter(1, particles)
	return particles
