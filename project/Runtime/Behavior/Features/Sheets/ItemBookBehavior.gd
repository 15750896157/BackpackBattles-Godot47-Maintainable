extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Sheets/ItemBook.gd")

static func prepareItemInstances(subject: Receiver):

	if Engine.get_physics_frames() <= subject.prepareDisableFrame: return
	if subject.prepareQueue.is_empty(): return

	var descriptor = subject.prepareQueue.pop_back()
	var item = descriptor.instantiate()
	Util.dictAppend(subject.preparedItemInstances, descriptor, item)

static func instantiateItem_pooled(subject: Receiver, descriptorOrName):
	var item
	if (descriptorOrName is String or descriptorOrName is StringName):
		item = subject.items[descriptorOrName].instantiate_pooled()
	else:
		item = descriptorOrName.instantiate_pooled()

	subject.call_deferred("emit_signal", "item_instantiated_deferred", item)
	return item

static func getItemIndex(subject: Receiver, item) -> int:
	if (item is String or item is StringName):
		return subject.items[item].itemIndex
	elif item is Item:
		return item.descriptor.itemIndex
	else:
		return item.itemIndex

static func getOwnedItems(subject: Receiver):
	var owned = Game.PLAYER.INVENTORY.getItemsAndGems()
	owned.append_array(Game.STORAGEBOX.getItemsAndGems())
	if (Game.draggedItem and
		not Game.draggedItem.sold and
		not Game.draggedItem in owned):
		owned.push_back(Game.draggedItem)
	return owned

static func getItemsInInventoryOfType(subject: Receiver, descriptor: ItemDescriptor) -> Array:
	if not descriptor in subject.ownableItems:
		return []

	var inInventory = []
	for item in subject.ownableItems[descriptor]:
		if (item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.Socket):
			inInventory.push_back(item)
	return inInventory

static func countItemsInInventoryOfType(subject: Receiver, descriptor) -> int:
	if not descriptor in subject.ownableItems:
		return 0

	var count = 0
	for item in subject.ownableItems[descriptor]:
		if (item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.Socket):
			count += 1
	return count

static func countPlacedItemsInInventoryOfType(subject: Receiver, descriptor) -> int:
	if not descriptor in subject.ownableItems:
		return 0

	var count = 0
	for item in subject.ownableItems[descriptor]:
		if ((item.placed and item.ownerType == Item.Owner.PlayerInventory) or
			item.ownerType == Item.Owner.Socket):
			count += 1
	return count

static func countOwnedItemsOfType(subject: Receiver, descriptor) -> int:
	if not descriptor in subject.ownableItems:
		return 0

	var count = 0
	for item in subject.ownableItems[descriptor]:
		if (item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.Socket or
			item.ownerType == Item.Owner.PlayerStorageBox):
			count += 1
	return count

static func isItemInInventory(subject: Receiver, descriptor) -> bool:
	if not descriptor in subject.ownableItems:
		return false

	for item in subject.ownableItems[descriptor]:
		if (item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.Socket):
			return true

	return false

static func isItemOwned(subject: Receiver, descriptor) -> bool:
	if not descriptor in subject.ownableItems:
		return false

	for item in subject.ownableItems[descriptor]:
		if (item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.PlayerStorageBox or
			item.ownerType == Item.Owner.Socket):
			return true

	return false

static func isItemOwnedAndWillNotBeConsumed(subject: Receiver, descriptor) -> bool:
	if not descriptor in subject.ownableItems:
		return false

	for item in subject.ownableItems[descriptor]:
		if ((item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.PlayerStorageBox or
			item.ownerType == Item.Owner.Socket) and
			not item.willBeConsumed):
			return true

	return false

static func getInventoryAsDict(subject: Receiver) -> Dictionary:
	var dict = Dictionary()
	for item in Game.PLAYER.INVENTORY.getItemsAndGems():
		Util.dictAppend(dict, item.descriptor, item)
	return dict

static func randomNonBagOfRarity(subject: Receiver, rarity, excludeDescriptors: Array, encountered: Array, numRolls: int):

	var forClass = Game.curClass
	if not Game.isClassUnlocked():
		forClass = Game.Classes.Ranger

	for bag in subject.bagsForRarity[rarity][forClass]:
		excludeDescriptors.push_back(bag)

	return subject.randomItemOfRarity(rarity, excludeDescriptors,
		encountered, numRolls)

static func randomWeaponOfRarity(subject: Receiver, rarity, excludeDescriptors: Array, encountered: Array, numRolls: int):

	var forClass = Game.curClass
	if not Game.isClassUnlocked():
		forClass = Game.Classes.Ranger

	var possibleItems = subject.curShopItems[rarity]

	for item in possibleItems:
		if not item.isStartingWeapon():
			excludeDescriptors.push_back(item)

	return subject.randomItemOfRarity(rarity, excludeDescriptors,
		encountered, numRolls)

static func addToShop(subject: Receiver, classI, item):

	if item.types[0] == Item.Type.Bag:
		subject.bagsForRarity[item.rarity][classI].push_back(item)

	item.shopItem = true

static func _process(subject: Receiver, delta):
	if Expedition.enabled: return
	if subject.itemPoolingIndex < subject.descriptorList.size() - 1:
		var scene = subject.descriptorList[subject.itemPoolingIndex].scene
		if scene != null:
			ObjectPool.prepare(scene, 2)
		subject.itemPoolingIndex += 1

	if (Game.state == Game.State.Shop or
		Game.buildHistory.isOpen):
		subject.call_deferred("prepareItemInstances")

static func addAppropriations(subject: Receiver):
	var speakWithAnimalsDescr = subject.getDescriptor("Speak with Animals")
	for petName in load("res://Items/Exclusive/SpeakwithAnimals.gd").get_script_constant_map().get("pets", []):
		subject.getDescriptor(petName).addAppropriatingItem(speakWithAnimalsDescr)

static func parseAppropriatingItems(subject: Receiver, item, line):
	var split = line.split(",")
	for itemName in split:
		itemName = itemName.strip_edges()
		item.appropriatingItems.push_back(subject.items[itemName])

static func calcRecipeTrees(subject: Receiver):
	for itemName in subject.items:
		var item = subject.items[itemName]
		if not item.originatingRecipes.is_empty():

			item.baseIngredients = subject.getBaseIngredients(item)
			item.recipeTree = subject.getRecipeTree(item)

static func getFoodOfRarity(subject: Receiver, rarity) -> ItemDescriptor:
	match rarity:
		Item.Rarity.Epic:
			rarity += 1 if Util.flip() else - 1

	return Util.pickRandomElement(subject.foodsForRarity[rarity])

static func getSubclassFromIndices(subject: Receiver, indices):
	for index in indices:
		var descr = subject.getDescriptorFromIndex(index)
		if descr.isSubclassItem():
			return descr.startsSubclass
		elif descr in subject.hyperCubes:
			return subject.hyperCubeDescriptor.startsSubclass
	return ""

static func canBeGifted(subject: Receiver, descriptor) -> bool:
	if descriptor.rarity == Item.Rarity.Unique:
		return false

	if descriptor.isTransient():
		return false

	for classI in Game.getNumClasses():
		if Game.isClassUnlocked(classI) and descriptor.isAvailableFor(classI):
			return true

	return false

static func getFullSkillPool(subject: Receiver) -> Array:
	var fullPool = []
	for roundI in [0, 1]:
		for skill in subject.skills[roundI]:
			if not skill in subject.nonGeneratableSkills:
				fullPool.push_back(skill)
	fullPool = Util.filterDuplicates(fullPool)
	return fullPool

static func addBaseIngredients(subject: Receiver, descriptor, ingredientCounter: Counter):
	if descriptor.originatingRecipes.is_empty():
		ingredientCounter.add(descriptor)
	else:
		var recipe = descriptor.originatingRecipes[0]
		for ingredient in recipe.getAllIngredients():
			if ingredient is ItemDescriptor:
				subject.addBaseIngredients(ingredient, ingredientCounter)

static func addIngredients(subject: Receiver, descriptor, treeItems: Counter):
	if not descriptor.originatingRecipes.is_empty():
		var recipe = descriptor.originatingRecipes[0]
		for ingredient in recipe.getAllIngredients():
			if ingredient is ItemDescriptor:
				subject.addIngredients(ingredient, treeItems)

static func getReleventIngredients(subject: Receiver, fromItems: Array, recipeItem: ItemDescriptor):
	var relevantIngredients = Counter.new()
	for item in fromItems:
		if subject.isInRecipeTree(item.descriptor, recipeItem):
			subject.addBaseIngredients(item.descriptor, relevantIngredients)
	return relevantIngredients

static func getShopItemsForClass(subject: Receiver, classI: int):
	var classItems = []
	for item in subject.classSpecificItems[classI]:
		if item.getRarity() < Item.Rarity.Unique or not item.isBag():
			classItems.push_back(item)
	return classItems
