extends Node

signal item_instantiated_deferred
signal pre_item_roll
signal item_rolled
signal items_counted

const NUM_PARAMS = 10
const NOT_ENCOUNTERED = - 1000
const NOT_SOLD = - 1001
const COMPLETION_THRESHOLD = 0.5
const COMPLETION_WEIGHT = 0.8
const DUAL_CLASS_WEIGHT = 2.0

var preparedItemInstances: Dictionary
var prepareQueue: Array
var prepareDisableFrame: int

var rarityWeightedBag = WeightedBag.new()
var randomItemWeightedBag = WeightedBag.new()

var table
var items: Dictionary
var shopBags: Array
var bagsForRarity: Array
var curShopClasses: int = ItemDescriptor.StuffedClasses.None
var curShopItems: Array
var descriptorList: Array
var sheetList: Array

var classSpecificItems: Array
var uniqueItems: Array
var subclassUniques: Array

var numSockets: Array

var gemIndex: Dictionary
var gemList: Array
var gemsForRarity: Array
var itemCounter: Dictionary
var ownableItems: Dictionary
var opponentItems: Dictionary

var boxOfRichesDescriptor
var deckOfCardsDescriptor
var crossbladesDescriptor
var missingCrossbladeIngredients
var recipeIngredientsWeights: Dictionary
var customerCardDescriptor
var platinCardDescriptor
var staminaSackDescriptor
var presentDescriptor
var flameDescriptor
var rainbowBadgeDescriptor
var stoneBadgeDescriptor
var forgingHammerDescriptor
var amuletDescriptor
var amuletOfFeastingDescriptor
var amulets: Array
var starOfCourageDescriptor
var toolboxDescriptor
var stableRecombobulatorDescriptor
var unstableRecombobulatorDescriptor
var extraBagsDescriptor
var spiritCompanionDescriptors: Array
var spiritBellsDescriptor
var bagOfGivingDescriptor
var chessboardDescriptor
var staffDescriptors: Array
var puzzleBags: Array
var snowmanDescriptor
var uniquelyUniqueDescriptor
var bagtacularDescriptor
var digDeeperDescriptor
var skills = [[], []]

var classBadges: Dictionary
var foodsForRarity: Array
var typesWithIcons: Array
var justStatsDescriptor
var moreStatsDescriptor
var unidentifiedSkillDescriptor
var nonGeneratableSkills: Dictionary
var puzzleboxDescriptor
var puzzleBadgeDescriptor
var sewingCaseDescriptor
var twineDescriptor
var arcaneIntellectDescriptor
var scrolls: Array
var books: Array
var fedoraDescriptor
var piggyOfRichesDescriptor
var piggies: Dictionary

var batteryDescriptor
var coilDescriptor
var chargeSplitterDescriptor
var manaCrystalDescriptor
var lightningStaffDescriptor
var boxofCogsDescriptor
var cogDescriptor
var generatorDescriptor
var cogBadgeDescriptor
var contraptronDescriptor
var bloodAmuletDescriptor
var magicRingDescriptor
var superiorRingDescriptor
var hyperCubeDescriptor
var hyperCubes = []

const amuletNames = [
	"Amulet of Life",
	"Amulet of Steel",
	"Amulet of Feasting",
	"Amulet of Darkness",
	"Amulet of Agility",
	"Amulet of the Wild",
	"Amulet of Alchemy",
	"Amulet of Fortune",
	"Amulet of Light"
	]

const typeToTextEffect = {
	Item.Type.Ice: ItemToolTip.TextEffect.Ice,
	Item.Type.Fire: ItemToolTip.TextEffect.Fire,
	Item.Type.Holy: ItemToolTip.TextEffect.Light,
	Item.Type.Vampiric: ItemToolTip.TextEffect.Vampiric,
	Item.Type.Dark: ItemToolTip.TextEffect.Spooky,
	Item.Type.Nature: ItemToolTip.TextEffect.Nature,
	Item.Type.Magic: ItemToolTip.TextEffect.Magic
}

func descriptorsFromItemList(_itemList) -> Array:
	var descriptors = []
	for item in _itemList:
		descriptors.push_back(item.descriptor)
	return descriptors

func descriptorsFromNameList(_nameList) -> Array:
	var descriptors = []
	for itemName in _nameList:
		descriptors.push_back(getDescriptor(itemName))
	return descriptors

func getDescriptor(itemName):
	return items[itemName]

func getNumItems() -> int:
	return items.size()

func getNumGems() -> int:
	return gemList.size()

func prepareInstance(descriptor, num = 1):
	if Expedition.enabled: return
	for i in num:
		prepareQueue.push_back(descriptor)

func pausePrepare(numFrames: int = 1):
	prepareDisableFrame = Engine.get_physics_frames() + numFrames

func prepareItemInstances():
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").prepareItemInstances(self)

func instantiateItem(descriptorOrName):
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").instantiateItem(self, descriptorOrName)

func instantiateItem_pooled(descriptorOrName):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").instantiateItem_pooled(self, descriptorOrName)

func instantiateItemFromIndex(index):
	return instantiateItem(getDescriptorFromIndex(index))

func getItemIndex(item) -> int:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getItemIndex(self, item)

func getDescriptorFromIndex(index: int) -> ItemDescriptor:
	return descriptorList[index]

func getOwnedItems():
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getOwnedItems(self)

func getOwnedAndReservedItems():
	var owned = getOwnedItems()
	owned.append_array(Game.shopSceneNode.getReservedItemsNoNull())
	return owned

func getInventoryStorageShopItems():
	return (Game.PLAYER.INVENTORY.getItemsAndGems() +
			Game.STORAGEBOX.getItemsAndGems() +
			Game.shopSceneNode.getItemsNoNull())

func isItemOnScreen(item) -> bool:
	var descriptor
	if (item is String or item is StringName):
		descriptor = getDescriptor(item)
	else:
		descriptor = item

	return descriptor in ownableItems

func isItemStashed(descriptor: ItemDescriptor) -> bool:
	var stashed = Game.shopSceneNode.getStashedReservedItems()
	return stashed != null and descriptor.itemIndex in stashed

func getItemsInInventoryOfType(descriptor: ItemDescriptor) -> Array:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getItemsInInventoryOfType(self, descriptor)

func countItemsInInventoryOfType(descriptor) -> int:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").countItemsInInventoryOfType(self, descriptor)

func countPlacedItemsInInventoryOfType(descriptor) -> int:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").countPlacedItemsInInventoryOfType(self, descriptor)

func countOwnedItemsOfType(descriptor) -> int:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").countOwnedItemsOfType(self, descriptor)

func getOwnedCounter() -> Dictionary:
	var counter = {}
	for descriptor in ownableItems:
		var count = countOwnedItemsOfType(descriptor)
		if count > 0:
			counter[descriptor] = count

	return counter

func isItemInInventory(descriptor) -> bool:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").isItemInInventory(self, descriptor)

func isItemInInventory_opponent(descriptor) -> bool:
	return descriptor in opponentItems

func getItemsOnScreenOfType(descriptor) -> Array:
	return ownableItems.get(descriptor, [])

func isItemOwned(descriptor) -> bool:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").isItemOwned(self, descriptor)

func isItemOwnedAndWillNotBeConsumed(descriptor) -> bool:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").isItemOwnedAndWillNotBeConsumed(self, descriptor)

func getItemsInInventoryOfType_opponent(descriptor) -> Array:
	return opponentItems.get(descriptor, [])

func countItemsInInventoryOfType_opponent(descriptor) -> int:
	return opponentItems.get(descriptor, []).size()

func getGemIndex(gem):

	return gemIndex[gem.getName()]

func getGemForIndex(index) -> ItemDescriptor:
	return gemList[index]

func instanciateGemFromIndex(index):
	return getGemForIndex(index).instantiate()

func getNumSockets(itemIndex):
	if numSockets[itemIndex] < 0:
		# New scenes still work before the developer rebuilds the metadata file.
		var scene = getDescriptorFromIndex(itemIndex).scene
		var count = 0
		if scene != null:
			var state = scene.get_state()
			for index in state.get_node_count():
				if str(state.get_node_name(index)).begins_with("GemSocket"): count += 1
		numSockets[itemIndex] = count
	return numSockets[itemIndex]

func generateItem(item):
	var generatedItem = instantiateItem(item)
	Game.incrementItemStatistic(Game.ItemStatistic.Acquired,
		generatedItem.descriptor)

	return generatedItem

func generateAndStorageItem(item, spawnPos: Vector2,
	targetPos: Vector2 = Game.STORAGEBOX.center + Util.randInBox(100, 100)):

	var generatedItem = generateItem(item)
	Game.playerNode.add_child(generatedItem)
	generatedItem.global_position = spawnPos
	generatedItem.pushToStorage(targetPos)
	return generatedItem

func countItems():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").countItems(self)

func getInventoryAsDict() -> Dictionary:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getInventoryAsDict(self)

func getRandomDescriptor():
	return Util.pickRandomElement(descriptorList)

func getRandomBagDescriptor():
	return Util.pickRandomElement(shopBags)

var weightFactor = 1.0
var weightBonus = 0.0

func addWeight(weight):
	weightBonus += weight

func multiplyWeight(factor):
	weightFactor *= factor

func randomItemOfRarity(rarity, excluded: Array,
	encountered: Array, numRolls: int):
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").randomItemOfRarity(self, rarity, excluded, encountered, numRolls)

func randomBagOfRarity(rarity, excludeDescriptors = []):
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").randomBagOfRarity(self, rarity, excludeDescriptors)

func randomNonBagOfRarity(rarity, excludeDescriptors: Array,
	encountered: Array, numRolls: int):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").randomNonBagOfRarity(self, rarity, excludeDescriptors, encountered, numRolls)

func randomWeaponOfRarity(rarity, excludeDescriptors: Array,
	encountered: Array, numRolls: int):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").randomWeaponOfRarity(self, rarity, excludeDescriptors, encountered, numRolls)

func getRandomTreasureDescriptor(maxPrice = 9000) -> ItemDescriptor:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").getRandomTreasureDescriptor(self, maxPrice)

func getRandomUnique() -> Item:
	return instantiateItem(getRandomTreasureDescriptor())

func getRandomRarity(_rarityOdds: Array):
	return rarityWeightedBag.rollOnce(_rarityOdds)

func getRandomItemWithRarityOdds(_rarityOdds: Array) -> ItemDescriptor:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").getRandomItemWithRarityOdds(self, _rarityOdds)

const validatorHeader = "extends Object"
const validatorFormatLine = "var {varName} = \"{hash}\""
var validatedResources = {
	"items": "res://Sheets/CSV/ItemData_e.csv",
	"ranger": "res://CharacterClasses/Ranger/Ranger.tres",
	"reaper": "res://CharacterClasses/Reaper/Reaper.tres",
	"berserker": "res://CharacterClasses/Berserker/Berserker.tres",
	"pyromancer": "res://CharacterClasses/Pyromancer/Pyromancer.tres"
}
var sheetKey = PackedByteArray()

func validateResources():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").validateResources(self)

func _ready() -> void :
	load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd")._ready(self)

func addToShop(classI, item):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").addToShop(self, classI, item)

var itemPoolingIndex = 0

func _process(delta):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd")._process(self, delta)

func addItemType(descriptor, type: int):
	descriptor.types.push_back(type)

func parseRecipe(baseItemDescriptor, recipesStr):
	var recipes = recipesStr.split(",")
	for recipeStr in recipes:
		var recipe = Recipe.new().fromString(baseItemDescriptor, recipeStr)

func addCauldronRecipes():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").addCauldronRecipes(self)

func calcClassAvailability():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").calcClassAvailability(self)

func ready_deferred():
	Game.itemLibrary.connect("items_initialized", Callable(self, "addAppropriations"))

func addAppropriations():
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").addAppropriations(self)

func parseAppropriatingItems(item, line):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").parseAppropriatingItems(self, item, line)

func initDescriptionKeys():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").initDescriptionKeys(self)

func detectMentionedStacks():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").detectMentionedStacks(self)

func calcRecipeTrees():
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").calcRecipeTrees(self)

func getGemOfRarity(rarity) -> ItemDescriptor:
	return Util.pickRandomElement(gemsForRarity[rarity])

func getFoodOfRarity(rarity) -> ItemDescriptor:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getFoodOfRarity(self, rarity)

func getNumInventoryUniques() -> int:
	var uniques = 0
	for item in Game.PLAYER.INVENTORY.getItemsAndGems():
		if item.descriptor.randomUniquePool:
			uniques += 1
	return uniques

func getOnScreenUniques(withShop = true):
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").getOnScreenUniques(self, withShop)

func getNumUniques(withShop = true) -> int:
	var numUniques = 0
	var uniques = getOnScreenUniques(withShop)
	for unique in uniques:
		numUniques += uniques[unique]
	return numUniques

func getMaxUniques() -> int:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").getMaxUniques(self)

func getTreasureCapacity() -> int:
	return getMaxUniques() - getNumUniques()

func getSubclassItemDescr(charClass):
	return subclassUniques[charClass].values()

func getPlayerSubclass():
	return getSubclass(Game.PLAYER.INVENTORY.getItems() + Game.STORAGEBOX.getItems())

func getSubclass(_items):
	for item in _items:
		if item.isSubclassItem():
			return item.descriptor.startsSubclass
	return ""

func getSubclassFromIndices(indices):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getSubclassFromIndices(self, indices)

func canBeGifted(descriptor) -> bool:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").canBeGifted(self, descriptor)

enum Filter{
	Treasures = 1,
	OtherClasses = 2,
	AnyRarity = 4,

	Gated = 8,
	Crafted = 16,
	Gems = 32,
	Amulets = 64,
	IgnoreWeight = 128,
	OnlyCrafted = 256,
}

func canBeGenerated(descriptor: ItemDescriptor, filters: int) -> bool:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").canBeGenerated(self, descriptor, filters)

func isAppropriatedByDigDeeper(descr):
	return descr.price >= 3 and descr.price <= 6

func isSpiritCompanion(descr: ItemDescriptor):
	return descr in spiritCompanionDescriptors

func canHaveMoreCompanions() -> bool:
	if isItemOwned(spiritBellsDescriptor):
		return true
	else:
		for spiritCompanion in spiritCompanionDescriptors:
			if isItemOnScreen(spiritCompanion):
				return false
	return true

func isRing(item) -> bool:
	return item.isA(magicRingDescriptor) or item.isA(superiorRingDescriptor)

func onOwnableItemAdded(item):

	Util.dictAppend(ownableItems, item.descriptor, item)

func onOwnableItemRemoved(item):
	Util.dictErase(ownableItems, item.descriptor, item)

func onOpponentItemAdded(item):
	Util.dictAppend(opponentItems, item.descriptor, item)

func cleanOwnableItems():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").cleanOwnableItems(self)

func printOwnableItems():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").printOwnableItems(self)

func updateClass(triggeringItem = null):
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").updateClass(self, triggeringItem)

func isAvailableForClasses(descriptor: ItemDescriptor):
	return (descriptor.classes == ItemDescriptor.StuffedClasses.Neutral or
			descriptor.isAvailableForStuffed(curShopClasses))

func onCharacterChanged():
	updateClass()

func onLoadoutChanged():
	updateClass()

func canGetForgingHammer(inventoryDict: Dictionary) -> bool:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").canGetForgingHammer(self, inventoryDict)

func getFullSkillPool() -> Array:
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getFullSkillPool(self)

func getSkillPool() -> Array:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").getSkillPool(self)

func getRandomSkills(num = 3) -> Array:
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd").getRandomSkills(self, num)

func getBaseIngredients(descriptor):
	var baseIngredients = Counter.new()
	addBaseIngredients(descriptor, baseIngredients)
	return baseIngredients

func addBaseIngredients(descriptor, ingredientCounter: Counter):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").addBaseIngredients(self, descriptor, ingredientCounter)

func getRecipeTree(descriptor):
	var treeItems = Counter.new()
	addIngredients(descriptor, treeItems)
	treeItems.remove(descriptor)
	return treeItems

func addIngredients(descriptor, treeItems: Counter):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").addIngredients(self, descriptor, treeItems)

func isInRecipeTree(item: ItemDescriptor, recipeItem: ItemDescriptor) -> bool:
	return recipeItem.recipeTree.has(item)

func getReleventIngredients(fromItems: Array, recipeItem: ItemDescriptor):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getReleventIngredients(self, fromItems, recipeItem)

func getRecipeCompletionWeight(item: ItemDescriptor):
	if item in recipeIngredientsWeights:
		return recipeIngredientsWeights[item]
	else:
		return 1.0

func getShopItemsForClass(classI: int):
	return load("res://Runtime/Behavior/Features/Sheets/ItemBookBehavior.gd").getShopItemsForClass(self, classI)

func _exit_tree():
	return load("res://Runtime/Behavior/Sheets/ItemBookBehavior.gd")._exit_tree(self)

