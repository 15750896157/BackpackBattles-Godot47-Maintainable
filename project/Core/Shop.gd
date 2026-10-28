extends Node2D

signal gate_item_roll
signal roll_sale
signal shop_refreshed

const shopOpenSound = preload("res://Assets/Sound/ShopBell.ogg")
const rerollSound = preload("res://Assets/Sound/Bell_short.ogg")
const throwOutSound = preload("res://Assets/Sound/Throwaway.mp3")
static var notEnoughGoldLabel = load("res://Interface/NotEnoughGoldLabel.tscn")
var highRollParticlesScene = load("res://Interface/HighRollParticles2D.tscn")
const skillRoundSound = preload("res://Assets/Sound/LevelUp1.ogg")

@onready var slots = [
	$ShopOffer1,
	$ShopOffer2,
	$ShopOffer3,
	$ShopOffer4,
	$ShopOffer5
]

@onready var shopSignLabel = $ShopLabel
@onready var chooseOneLabel = $ChooseOneLabel
@onready var itemOffScreenIndicator = $OffScreenItemIndicator

@onready var redArrowAnimation = $Reroll/RedArrowAnimationPlayer
@onready var redArrow = $Reroll/RedArrow
@onready var rarityChart = $ShopSign/RarityChart

var rarityOdds = [
	[0.9, 0.1, 0.0, 0.0, 0.0],
	[0.84, 0.15, 0.01, 0.0, 0.0],
	[0.75, 0.2, 0.05, 0.0, 0.0],
	[0.64, 0.25, 0.1, 0.01, 0.0],
	[0.45, 0.35, 0.15, 0.05, 0.0],
	[0.29, 0.4, 0.2, 0.1, 0.01],
	[0.2, 0.35, 0.25, 0.15, 0.05],
	[0.2, 0.3, 0.25, 0.15, 0.1],
	[0.2, 0.28, 0.25, 0.15, 0.12],
	[0.2, 0.25, 0.25, 0.15, 0.15],
	[0.2, 0.23, 0.23, 0.17, 0.17],
	[0.2, 0.2, 0.2, 0.2, 0.2]
]

var gateItemCandidates: Array

@onready var megaCloverDescriptor = ItemBook.getDescriptor("Mega Clover")
@onready var kingoftheBlingDescriptor = ItemBook.getDescriptor("King of the Bling")

var itemsBoughtThisRound: int
var rerollsThisRound: int
var rerollsThisRun: int
var rollsThisRun: int
var saleAcc = 0.0

var saleSlots = []
var stashedItems = []
var stashedSales = []
var stashedItemData = []
var encounteredRoll: Array
var rerolledRoll: Array
const REROLL_THRESHOLD1 = 4
const REROLL_THRESHOLD2 = 9999999
const SALE_CHANCE = 0.1
const UNIQUE_CHANCES = [
	0.3, 0.2, 0.2, 0.07

	]
var rolledUnique = null
var uniqueAcc = 0.0
var chooseOneShop: bool = false
var bonusSaleChance: float
var reservedItemsCounter: Dictionary

func _ready() -> void :
	load("res://Runtime/Behavior/Core/ShopBehavior.gd")._ready(self)

func resetRerollCounter():
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").resetRerollCounter(self)

func getRerollCost() -> int:
	return Expedition.flow.economy.refresh_cost(Expedition.flow.run) if Expedition.active else 1

func getRerollProgress() -> float:
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").getRerollProgress(self)

func enteringShop():
	rerollsThisRound = int(Expedition.flow.run.get("shop", {}).get("refresh_count", 0))
	return

func openShop():
	chooseOneShop = false
	chooseOneLabel.hide()
	shopSignLabel.show()
	Sound.playSound(shopOpenSound)
	Expedition.request_render()
	return

func closeShop():
	Util.callDelayed(self, "shopHidden", 2)
	return

func shopHidden():
	chooseOneShop = false

	resetAll()

func stashItems():
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").stashItems(self)

func resetAll():
	for slot in slots:
		slot.reset()

func throwAllOut():
	for slot in slots:
		slot.throwOut()

func unstashItems():
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").unstashItems(self)

func showChooseOneSign():
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").showChooseOneSign(self)

func showSubclassShop():
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").showSubclassShop(self)

func onChooseOneItemBought(item):
	Game.onSpecialItemBought(item)
	endChooseOneShop()
	rollItems(getHighRollBuckets(), getUniqueSlots(), item)

func showNormalShop():
	Expedition.request_render()
	return

func showSkillShop():
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").showSkillShop(self)

func endChooseOneShop():
	chooseOneShop = false
	chooseOneLabel.hide()
	shopSignLabel.show()
	throwAllOut()
	unstashItems()
	rarityChart.appear()
	bannerTimer.stop()

func getUniqueSlots() -> Array:
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").getUniqueSlots(self)

func getSaleChance(item = null):
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").getSaleChance(self, item)

func getUniqueChance():
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").getUniqueChance(self)

func getNonReservedSlotIndices():
	var nonReservedSlots = []
	for i in slots.size():
		if not slots[i].reserved:
			nonReservedSlots.push_back(i)

	return nonReservedSlots

func getHighRollBuckets():
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").getHighRollBuckets(self)

func addGateItem(item):
	gateItemCandidates.push_back(item)

func getFreeSlot(excludedSlots) -> int:
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").getFreeSlot(self, excludedSlots)

func getRarityOddsForCurRound():
	var index = min(rarityOdds.size() - 1, Game.curRound - 1)
	return rarityOdds[index]

func isFirstShop() -> bool:
	return Game.curRound == 1 and rerollsThisRound == 0

func hasWeapon(items) -> bool:
	for item in items:
		if item.descriptor.isStartingWeapon():
			return true
	return false

func rollItems(highRollBuckets = [0, 0, 0, 0, 0], uniqueSlots = [], triggeringSubclassItem = null):
	Expedition.request_render()
	return

func resetBagPity():
	Game.bagPityCounter = [0, 1, 2].pick_random()

func checkSalesAch():
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").checkSalesAch(self)

func clear():
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").clear(self)

func setItem(slotIndex, item):
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").setItem(self, slotIndex, item)

func setBought(slotIndex):
	slots[slotIndex].resetFull()

func setReserved(slotIndex, reserved):
	slots[slotIndex].setReserved(reserved)

func setOnSale(slotIndex, onSale):
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").setOnSale(self, slotIndex, onSale)

func setStashedReservedItems(_stashedItems):
	if _stashedItems != null:

		stashedItems = _stashedItems.duplicate()

func setStashedSales(_stashedSales):
	if _stashedSales != null:
		stashedSales = _stashedSales.duplicate()

func setStashedItemData(_stashedItemData):
	if _stashedItemData != null:
		stashedItemData = _stashedItemData.duplicate()

func getItems():
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").getItems(self)

func getItemsNoNull():
	return Util.filterNull(getItems())

func getReservedSlots():
	var reserved = []
	for i in slots.size():
		reserved.push_back(slots[i].reserved)
	return reserved

func getReservedItemsNoNull():
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").getReservedItemsNoNull(self)

func getSaleSlots():
	var onSale = []
	for i in slots.size():
		onSale.push_back(slots[i].onSale)
	return onSale

func getStashedReservedItems():
	if chooseOneShop:
		return stashedItems.duplicate()
	else:
		return null

func getStashedSales():
	if chooseOneShop:
		return stashedSales.duplicate()
	else:
		return null

func getStashedItemData():
	if chooseOneShop:
		return stashedItemData.duplicate()
	else:
		return null

func reroll():
	Expedition.bridge.refresh_shop()
	return

func spawnHighRollParticles(slotIndex):
	return load("res://Runtime/Behavior/Features/Core/ShopBehavior.gd").spawnHighRollParticles(self, slotIndex)

func rollSale(slot) -> bool:
	return load("res://Runtime/Behavior/Core/ShopBehavior.gd").rollSale(self, slot)

func addBonusSalesChance(chance):
	bonusSaleChance += chance

var bannerTween: Tween
@onready var bannerTimer = $BannerTimer

func onItemPickedUp():
	return

func onItemDropped(item, dropResult: int):
	return

var nextHighlightSlot: int
const bannerHightlightColor = Color(1.4, 1.4, 1.4)
const bannerHighlightDur = 2.3
const bannerHighlightDur2 = 2.69
const bannerHighlightInterval = 5.0
const highlightSlots = [1, 0, 4, 2, 3]

func onBannerTimerTimeout():
	bannerTimer.stop()
	return

func onItemBought(item, slot):
	itemsBoughtThisRound += 1
	return

static func notEnoughGold(pos):
	var label = ObjectPool.instantiate(notEnoughGoldLabel)
	Game.UINode.add_child(label)
	label.global_position = pos
