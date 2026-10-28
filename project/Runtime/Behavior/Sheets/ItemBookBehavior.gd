extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Sheets/ItemBook.gd")

static func instantiateItem(subject: Receiver, descriptorOrName):
	var item
	var descriptor
	if (descriptorOrName is String or descriptorOrName is StringName):
		descriptor = subject.items[descriptorOrName]
	else:
		descriptor = descriptorOrName

	if descriptor in subject.preparedItemInstances:
		item = Util.dictPop(subject.preparedItemInstances, descriptor)

		subject.prepareInstance(descriptor)
	else:
		item = descriptor.instantiate()

	subject.call_deferred("emit_signal", "item_instantiated_deferred", item)
	return item

static func countItems(subject: Receiver):
	subject.itemCounter.clear()
	for item in subject.getOwnedAndReservedItems():
		Util.dictAdd(subject.itemCounter, item.descriptor, 1)
		if item.descriptor.baseIngredients:
			Util.dictAddDict(subject.itemCounter, item.descriptor.baseIngredients.dict)

	subject.missingCrossbladeIngredients = Counter.new().fromCounter(subject.crossbladesDescriptor.baseIngredients)
	var ingredientsInInventory = subject.getReleventIngredients(
		Game.PLAYER.INVENTORY.getItems(), subject.crossbladesDescriptor)
	var ingredientsInStorage = subject.getReleventIngredients(
		Game.STORAGEBOX.getItems(), subject.crossbladesDescriptor)

	ingredientsInInventory.addCounter(ingredientsInStorage)
	var numBaseIngredients = subject.missingCrossbladeIngredients.countAll()
	subject.missingCrossbladeIngredients.removeCounter(ingredientsInInventory)
	var numMissingIngredients = subject.missingCrossbladeIngredients.countAll()

	subject.recipeIngredientsWeights.clear()

	for item in subject.missingCrossbladeIngredients.dict:
		var completion = 1.0 - numMissingIngredients / float(numBaseIngredients)

		if completion > subject.COMPLETION_THRESHOLD:
			subject.recipeIngredientsWeights[item] = 1.0 + subject.COMPLETION_WEIGHT * (completion - subject.COMPLETION_THRESHOLD)

	subject.emit_signal("items_counted")

static func randomItemOfRarity(subject: Receiver, rarity, excluded: Array, encountered: Array, numRolls: int):

	var forClass = Game.curClass
	if not Game.isClassUnlocked():
		forClass = Game.Classes.Ranger

	var possibleItems = subject.curShopItems[rarity].duplicate()

	possibleItems = Util.subtractArr(possibleItems, excluded)

	var uniqueDescriptors = []

	if Game.state == Game.State.Shop:
		var otherItems = subject.getOwnedAndReservedItems()
		for item in otherItems:
			if item.descriptor.canOnlyExistOnce():
				uniqueDescriptors.push_back(item.descriptor)

			if item.descriptor in subject.spiritCompanionDescriptors:
				if not subject.isItemOwned(subject.spiritBellsDescriptor):
					uniqueDescriptors.append_array(subject.spiritCompanionDescriptors)

		for descriptor in excluded:
			if descriptor in subject.spiritCompanionDescriptors:
				if not subject.isItemOwned(subject.spiritBellsDescriptor):
					uniqueDescriptors.append_array(subject.spiritCompanionDescriptors)

		possibleItems = Util.subtractArr(possibleItems, uniqueDescriptors)

	if possibleItems.is_empty():
		possibleItems = excluded

	var weights = Array()
	for item in possibleItems:
		var thresholdWeight = item.getThresholdWeight(subject.itemCounter)
		var weight = item.getWeight()
		weight *= thresholdWeight
		weight *= subject.getRecipeCompletionWeight(item)
		var lastEncounter = numRolls - encountered[item.itemIndex]
		if encountered[item.itemIndex] == subject.NOT_ENCOUNTERED:
			weight *= 2.3
		elif lastEncounter > 5 and thresholdWeight >= 1.0:
			weight *= 1.4
		elif lastEncounter < 3 and not item.isBag():
			weight *= 0.1

		subject.weightBonus = weight
		subject.weightFactor = 1.0
		subject.emit_signal("pre_item_roll", item)

		weights.push_back(subject.weightBonus * subject.weightFactor)

	Util.eassert(weights.size() == possibleItems.size())
	var index = subject.randomItemWeightedBag.rollOnce(weights)
	var descriptor = possibleItems[index]

	subject.emit_signal("item_rolled", descriptor)

	return subject.instantiateItem(descriptor)

static func randomBagOfRarity(subject: Receiver, rarity, excludeDescriptors):

	if subject.bagsForRarity[rarity][Game.curClass].is_empty():
		rarity = Item.Rarity.Common

	var descriptor = Util.pickRandomElement(subject.bagsForRarity[rarity][Game.curClass])
	for i in 3:
		if not excludeDescriptors.has(descriptor):
			break
		descriptor = Util.pickRandomElement(subject.bagsForRarity[rarity][Game.curClass])

	return subject.instantiateItem(descriptor)

static func getRandomTreasureDescriptor(subject: Receiver, maxPrice) -> ItemDescriptor:
	var onScreenUniques = subject.getOnScreenUniques()
	var weights = Array()
	for item in subject.uniqueItems:
		var weight
		if (item.getPrice() > maxPrice or
			Game.curRound < item.earliestRound or
			Game.curRound > item.latestRound or
			item == subject.classBadges[Game.curClass] or
			item in onScreenUniques or
			(item == subject.puzzleBadgeDescriptor and subject.isItemOwned(subject.puzzleboxDescriptor))):
			weight = 0
		else:
			weight = item.getWeight()

		weights.push_back(weight)

	var index = subject.randomItemWeightedBag.rollOnce(weights)
	return subject.uniqueItems[index]

static func getRandomItemWithRarityOdds(subject: Receiver, _rarityOdds: Array) -> ItemDescriptor:
	var rarity = subject.getRandomRarity(_rarityOdds)
	var possibleItems = []
	var forClass = Game.curClass
	if not Game.isClassUnlocked():
		forClass = Game.Classes.Ranger

	for descriptor in subject.descriptorList:
		if descriptor.rarity == rarity and descriptor.isAvailableFor(forClass):
			possibleItems.push_back(descriptor)

	return Util.pickRandomElement(possibleItems)

static func validateResources(subject: Receiver):
	# Recovered source uses the verified plaintext table so it can be edited.
	if ProjectSettings.get_setting("application/config/recovered_project"):
		return
	for i in 32:
		subject.sheetKey.append(i)
	if Game.EDITOR:
		var file1: File = File.new()
		file1.open("res://Sheets/CSV/ItemData.csv", File.READ)
		var data = file1.get_as_text()
		var file2 = File.new()
		file1.open_encrypted("res://Sheets/CSV/ItemData_e.csv", File.WRITE, subject.sheetKey)
		file1.store_string(data)
		file1.close()
		file2.close()

	var file = File.new()

	if Game.EDITOR:
		file.open("res://Utility/DataValidator.gd", File.WRITE)
		file.store_line(subject.validatorHeader)
		for res in subject.validatedResources:
			var md5 = file.get_md5(subject.validatedResources[res])
			file.store_line(subject.validatorFormatLine.format({
				"varName": res,
				"hash": md5
				}))
		file.close()
	else:
		var validator = load("res://Utility/DataValidator.gd").new()
		for res in subject.validatedResources:
			var md5 = file.get_md5(subject.validatedResources[res])
			if validator.get(res) != md5:
				print("loading error 2")
				subject.get_tree().quit()
		validator.free()

static func _ready(subject: Receiver) -> void :
	subject.process_mode = Node.PROCESS_MODE_ALWAYS
	subject.validateResources()

	Game.connect("character_changed", Callable(subject, "onCharacterChanged"))
	Game.connect("loadout_changed", Callable(subject, "onLoadoutChanged"))

	if Game.loadExclusiveContent():
		for locale in Game.locales.values():
			TranslationServer.add_translation(load("res://Sheets/CSV/ExclusiveItems." + locale + ".translation"))

	if Game.loadUnreleasedContent():
		for locale in Game.locales.values():
			TranslationServer.add_translation(load("res://Sheets/CSV/Unreleased." + locale + ".translation"))

	for rarity in Item.Rarity:
		var arr1 = []
		var arr2 = []
		for classI in Game.getNumClasses():
			arr1.push_back([])
			arr2.push_back([])

		subject.bagsForRarity.push_back(arr2)
		subject.gemsForRarity.push_back([])
		subject.foodsForRarity.push_back([])

	for classI in Game.getNumClasses():
		subject.classSpecificItems.push_back([])
		subject.subclassUniques.push_back({})

	for type in Item.Type:
		if type.to_lower() in Util.icons:
			subject.typesWithIcons.push_back(type)

	if Game.PLAYTEST and SteamHelper.STEAMDECK and OS.is_debug_build():
		subject.table = Table.new().loadFromCsv("res://Sheets/CSV/ItemData.csv")
	else:
		if ProjectSettings.get_setting("application/config/recovered_project"):
			subject.table = Table.new().loadFromCsv("res://Sheets/CSV/ItemData.csv")
		else:
			subject.table = Table.new().loadFromCsv("res://Sheets/CSV/ItemData_e.csv", subject.sheetKey)

	var dir = LegacyDirectory.new()

	for line in subject.table.countRows() - 1:

		var item = ItemDescriptor.new()

		var itemName = subject.table.getStr("name", line)
		item.identifier = itemName

		var itemSet = subject.table.getStr("demo", line)
		if itemSet == "no":
			item.releaseState = ItemDescriptor.ReleaseState.Full
		elif itemSet == "nooo":
			item.releaseState = ItemDescriptor.ReleaseState.Unreleased
		else:
			item.releaseState = ItemDescriptor.ReleaseState.Demo

		var mainType = subject.table.getStr("type", line)
		if mainType == "Melee Weapon":
			item.types.push_back(Item.Type.Weapon)
			subject.call_deferred("addItemType", item, Item.Type.Melee)
		elif mainType == "Ranged Weapon":
			item.types.push_back(Item.Type.Weapon)
			subject.call_deferred("addItemType", item, Item.Type.Ranged)

		else:
			item.types.push_back(subject.table.getEnu("type", Item.Type, line))

		var extraTypes = subject.table.getStr("extraTypes", line).replace(" ", "").split(",")
		for type in extraTypes:
			if type != "":
				item.types.push_back(Item.Type[type])

		var itemNameNoSpaces = itemName.replace(" ", "")
		var scenePath = "Items/" + itemNameNoSpaces + ".tscn"

		if item.types[0] == Item.Type.Gem:
			scenePath = "Items/Gems/" + itemNameNoSpaces + ".tscn"

		if dir.file_exists(scenePath):
			item.scene_path = "res://" + scenePath.trim_prefix("res://")
		else:
			if Game.loadExclusiveContent():
				if item.types[0] == Item.Type.ChessPiece:
					scenePath = "Items/Exclusive/Chess/" + itemNameNoSpaces + ".tscn"
				else:
					scenePath = "Items/Exclusive/" + itemNameNoSpaces + ".tscn"
				if dir.file_exists(scenePath):
					item.scene_path = "res://" + scenePath.trim_prefix("res://")

				elif Game.loadUnreleasedContent():
					scenePath = "Items/Exclusive/Unreleased/" + itemNameNoSpaces + ".tscn"
					item.scene_path = "res://" + scenePath.trim_prefix("res://")

		var aniPath = "Items/Animations/" + itemNameNoSpaces + "Animation.tscn"
		if dir.file_exists(aniPath):
			item.animation_path = "res://" + aniPath.trim_prefix("res://")
		else:
			if Game.loadExclusiveContent():
				aniPath = "Items/Exclusive/Animations/" + itemNameNoSpaces + "Animation.tscn"
				if dir.file_exists(aniPath):
					item.animation_path = "res://" + aniPath.trim_prefix("res://")
				elif Game.loadUnreleasedContent():
					aniPath = "Items/Exclusive/Unreleased/" + itemNameNoSpaces + "Animation.tscn"
					if dir.file_exists(aniPath):
						item.animation_path = "res://" + aniPath.trim_prefix("res://")

		var shop = subject.table.getStr("shop", line)
		var classes = ItemDescriptor.StuffedClasses.Undefined
		item.version = Game.versionToInt(subject.table.getStr("version", line))

		var loadItem = item.isReleased()

		if loadItem:
			# Local views use footprint-relative ItemMotion, not old scene animations.
			if not Expedition.enabled and (item.isWeapon() or item.types[0] == Item.Type.Potion):
				if item.animation_path.is_empty():
					Util.eprint(itemName, " has no animation")

			subject.table.fillList(item, ["minDam", "maxDam", "price",
				"accuracy", "chance", "chance2", "shopChance", "staminaCost", "block",
				"threshold", "weight", "earliestRound", "latestRound"], line)

			var cds = subject.table.getStr("cd", line).replace(" ", "").split(",")
			if cds.size() > 0:
				item.cd = float(cds[0])
			for i in range(1, cds.size()):
				item.extraCds.push_back(float(cds[i]))

			item.rarity = subject.table.getEnu("rarity", Item.Rarity, line)

			var requiredItemStr = subject.table.getStr("requires", line)
			if requiredItemStr != "":
				item.requiredItem = subject.getDescriptor(requiredItemStr)

			if item.isBag() and item.rarity != Item.Rarity.Unique:
				subject.shopBags.push_back(item)

			item.tags = subject.table.getFlags("tags", Item.Tag, line)
			item.material = subject.table.getEnu("material", Item.Mat, line, Item.Mat.Default)
			item.physics = subject.table.getEnu("physics", Item.Physics, line, Item.Physics.Default)
			var textEffect = subject.table.getEnu("textEffect", ItemToolTip.TextEffect, line, ItemToolTip.TextEffect.NotSet)
			if textEffect == ItemToolTip.TextEffect.NotSet:
				item.textEffect = ItemToolTip.TextEffect.None

				for type in item.types:
					if type in subject.typeToTextEffect:
						item.textEffect = subject.typeToTextEffect[type]
						break
			else:
				item.textEffect = textEffect

			var paramI = 0
			for colI in subject.NUM_PARAMS:
				var col = "p" + str(colI + 1)
				var colStr = subject.table.getStr(col, line)
				if "," in colStr:
					var paramSubList = colStr.split(",")
					for split in paramSubList:
						var split2 = split.split(":")
						var paramVal = float(split2[0])
						item.addNamedParam(split2[1], paramVal)

						item.params.push_back(paramVal)
						paramI += 1
				else:
					var paramVal = subject.table.getFloat(col, line, 0)
					var paramName = subject.table.getParamName(col, line)
					if paramName != "":
						item.addNamedParam(paramName, paramVal)

					item.params.push_back(paramVal)
					paramI += 1

			item.gainedStacks = subject.table.getFlags("gain", Item.Stack, line)
			item.removedStacks = subject.table.getFlags("remove", Item.Stack, line)
			item.usedStacks = subject.table.getFlags("use", Item.Stack, line)

			if subject.table.getStr("canActivate", line) == "no":
				item.canActivate = false

			if item.isBag():
				item.activationAni = Item.ActivationAni.Scale
			elif item.hasType(Item.Type.Potion):
				item.activationAni = Item.ActivationAni.Potion
			else:
				item.activationAni = subject.table.getEnu("animation", Item.ActivationAni, line,
					Item.ActivationAni.Jump)

			if shop == "":
				classes = ItemDescriptor.StuffedClasses.Neutral
				for classI in Game.getNumClasses():
					subject.addToShop(classI, item)
			elif shop == "no":
				classes = ItemDescriptor.StuffedClasses.None
			elif shop == "unique":
				classes = ItemDescriptor.StuffedClasses.Neutral
				subject.uniqueItems.push_back(item)
				item.randomUniquePool = true
			elif shop == "special":

				classes = ItemDescriptor.StuffedClasses.Neutral
			elif ">" in shop:
				var parts = shop.split(">")
				var className = parts[0]
				var subclassName = parts[1]

				var classI = Game.getClassEnum()[className]
				subject.subclassUniques[classI][subclassName] = item
				item.startsSubclass = subclassName
				classes = ItemDescriptor.stuffClassIndex(classI)

			elif item.hasType(Item.Type.Skill):
				var split: Array = shop.split(" ")
				var classList = split[0].split(",")
				classes = ItemDescriptor.StuffedClasses.None
				for className in classList:
					classes += ItemDescriptor.StuffedClasses[className]
				var rounds = split[1].split(",")

				for skillRound in rounds:
					subject.skills[int(skillRound) - 1].push_back(item)

					if int(skillRound) == 1:
						item.appearRounds.push_back(Game.SKILL_ROUND1)
					else:
						item.appearRounds.push_back(Game.SKILL_ROUND2)

			else:
				var classI = Game.getClassEnum()[shop]
				classes = ItemDescriptor.stuffClassIndex(classI)

				subject.classSpecificItems[classI].push_back(item)
				subject.addToShop(classI, item)

			if item.hasType(Item.Type.Food):
				subject.foodsForRarity[item.rarity].push_back(item)

			if item.hasTag(Item.Tag.Staff):
				subject.staffDescriptors.push_back(item)

		item.classes = classes

		subject.items[itemName] = item
		var index = subject.table.getInt("id", line)
		item.itemIndex = index

		item.sheetIndex = subject.sheetList.size()
		subject.sheetList.push_back(item)
		if item.types[0] == Item.Type.Gem:
			subject.sheetList.push_back(item)
			subject.sheetList.push_back(item)

	subject.descriptorList.resize(subject.getNumItems())
	for item in subject.items.values():
		if subject.descriptorList[item.itemIndex] != null:
			print("duplicate item index ", item.itemIndex)
		subject.descriptorList[item.itemIndex] = item

	for itemName in subject.items:
		if subject.items[itemName].types[0] == Item.Type.Gem:
			subject.gemIndex[itemName] = subject.gemList.size()
			subject.gemList.push_back(subject.items[itemName])

	# Socket metadata is exported from the recovered scenes, without constructing them.
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://PvE/asset_catalog.json"))
	var scene_rows: Dictionary = catalog.get("items", {}) if catalog is Dictionary else {}
	subject.numSockets.resize(subject.getNumItems())
	for item in subject.items.values():
		subject.numSockets[item.itemIndex] = int(scene_rows.get(item.getName(), {}).get("sockets", -1))

	subject.boxOfRichesDescriptor = subject.getDescriptor("Box of Riches")
	subject.deckOfCardsDescriptor = subject.getDescriptor("Deck of Cards")
	subject.crossbladesDescriptor = subject.getDescriptor("Crossblades")
	subject.platinCardDescriptor = subject.getDescriptor("Platin Customer Card")
	subject.customerCardDescriptor = subject.getDescriptor("Customer Card")
	subject.staminaSackDescriptor = subject.getDescriptor("Stamina Sack")

	subject.presentDescriptor = subject.getDescriptor("Present")
	subject.flameDescriptor = subject.getDescriptor("Flame")
	subject.forgingHammerDescriptor = subject.getDescriptor("Forging Hammer")
	subject.amuletDescriptor = subject.getDescriptor("Amulet Unidentified")
	subject.amuletOfFeastingDescriptor = subject.getDescriptor("Amulet of Feasting")
	for amulet in subject.amuletNames:
		subject.amulets.push_back(subject.getDescriptor(amulet))

	subject.starOfCourageDescriptor = subject.getDescriptor("Star of Courage")
	subject.toolboxDescriptor = subject.getDescriptor("Toolbox")
	subject.stableRecombobulatorDescriptor = subject.getDescriptor("Stable Recombobulator")
	subject.unstableRecombobulatorDescriptor = subject.getDescriptor("Unstable Recombobulator")
	subject.extraBagsDescriptor = subject.getDescriptor("Extra Bags")

	subject.classBadges[Game.Classes.Ranger] = subject.getDescriptor("Leaf Badge")
	subject.classBadges[Game.Classes.Reaper] = subject.getDescriptor("Skull Badge")
	subject.classBadges[Game.Classes.Berserker] = subject.getDescriptor("Wolf Badge")
	subject.classBadges[Game.Classes.Pyromancer] = subject.getDescriptor("Flame Badge")
	subject.classBadges[Game.Classes_Full.Mage] = subject.getDescriptor("Magic Badge")
	subject.classBadges[Game.Classes_Full.Adventurer] = subject.getDescriptor("Twine Badge")
	subject.classBadges[Game.Classes_Full.Engineer] = subject.getDescriptor("Cog Badge")

	subject.rainbowBadgeDescriptor = subject.getDescriptor("Rainbow Badge")
	subject.stoneBadgeDescriptor = subject.getDescriptor("Stone Badge")

	subject.spiritCompanionDescriptors.push_back(subject.getDescriptor("Cat Spirit"))
	subject.spiritCompanionDescriptors.push_back(subject.getDescriptor("Badger Spirit"))
	subject.spiritCompanionDescriptors.push_back(subject.getDescriptor("Owl Spirit"))
	subject.spiritBellsDescriptor = subject.getDescriptor("Spirit Bells")
	subject.bagOfGivingDescriptor = subject.getDescriptor("Bag of Giving")
	subject.chessboardDescriptor = subject.getDescriptor("Chess Board")

	subject.scrolls.push_back(subject.getDescriptor("Spell Scroll Ice"))
	subject.scrolls.push_back(subject.getDescriptor("Spell Scroll Nature"))
	subject.scrolls.push_back(subject.getDescriptor("Spell Scroll Light"))
	subject.scrolls.push_back(subject.getDescriptor("Spell Scroll Dark"))

	subject.books.push_back(subject.getDescriptor("Book of Ice"))
	subject.books.push_back(subject.getDescriptor("Book of Nature"))
	subject.books.push_back(subject.getDescriptor("Book of Light"))
	subject.books.push_back(subject.getDescriptor("Book of Darkness"))

	subject.snowmanDescriptor = subject.getDescriptor("Snowman")
	subject.uniquelyUniqueDescriptor = subject.getDescriptor("Uniquely Unique")
	subject.bagtacularDescriptor = subject.getDescriptor("Bagtacular")
	subject.justStatsDescriptor = subject.getDescriptor("Just Stats")
	subject.moreStatsDescriptor = subject.getDescriptor("More Stats")
	subject.unidentifiedSkillDescriptor = subject.getDescriptor("Unidentified Skill")
	subject.nonGeneratableSkills[subject.justStatsDescriptor] = true
	subject.nonGeneratableSkills[subject.moreStatsDescriptor] = true
	subject.nonGeneratableSkills[subject.unidentifiedSkillDescriptor] = true

	subject.digDeeperDescriptor = subject.getDescriptor("Dig Deeper")
	subject.puzzleboxDescriptor = subject.getDescriptor("Puzzlebox")
	subject.puzzleBadgeDescriptor = subject.getDescriptor("Puzzle Badge")
	subject.sewingCaseDescriptor = subject.getDescriptor("Sewing Case")
	subject.twineDescriptor = subject.getDescriptor("Twine")
	subject.arcaneIntellectDescriptor = subject.getDescriptor("Arcane Intellect")
	subject.fedoraDescriptor = subject.getDescriptor("Fedora")
	subject.piggyOfRichesDescriptor = subject.getDescriptor("Piggy of Riches")

	for puzzleBag in ["L", "S", "Z", "T", "J"]:
		subject.puzzleBags.push_back(subject.getDescriptor("Puzzlebag " + puzzleBag))

	subject.piggies[subject.piggyOfRichesDescriptor] = true
	subject.piggies[subject.getDescriptor("Piggybank")] = true
	subject.piggies[subject.getDescriptor("Lucky Piggy")] = true

	subject.batteryDescriptor = subject.getDescriptor("Battery")
	subject.coilDescriptor = subject.getDescriptor("Coil")
	subject.chargeSplitterDescriptor = subject.getDescriptor("Charge Splitter")
	subject.manaCrystalDescriptor = subject.getDescriptor("Mana Crystal")
	subject.lightningStaffDescriptor = subject.getDescriptor("Lightning Staff")
	subject.boxofCogsDescriptor = subject.getDescriptor("Engineer Bag 2")
	subject.cogDescriptor = subject.getDescriptor("Cog")
	subject.generatorDescriptor = subject.getDescriptor("Generator")
	subject.cogBadgeDescriptor = subject.getDescriptor("Cog Badge")
	subject.contraptronDescriptor = subject.getDescriptor("Con-Trap-Tron")
	subject.bloodAmuletDescriptor = subject.getDescriptor("Blood Amulet")
	subject.magicRingDescriptor = subject.getDescriptor("Magic Ring")
	subject.superiorRingDescriptor = subject.getDescriptor("Superior Ring")
	subject.hyperCubeDescriptor = subject.getDescriptor("Hypercube")
	subject.hyperCubes.push_back(subject.getDescriptor("Chrome Cube"))
	subject.hyperCubes.push_back(subject.getDescriptor("Gold Cube"))
	subject.hyperCubes.push_back(subject.getDescriptor("Plastic Cube"))
	subject.hyperCubes.push_back(subject.getDescriptor("Bismuth Cube"))

	for line in subject.table.countRows() - 1:
		var index = subject.table.getInt("id", line)
		var item = subject.descriptorList[index]

		if not item.isReleased():
			continue

		var gateItemStr = subject.table.getStr("gateItem", line)
		if gateItemStr != "":
			item.gateItem = subject.getDescriptor(gateItemStr)
			item.gateItem.gatedItems.push_back(item)

		if item.types[0] == Item.Type.Gem:
			if gateItemStr == "Box of Riches":
				subject.gemsForRarity[item.rarity].push_back(item)

		var recipesStr = subject.table.getStr("recipes", line)
		if recipesStr != "":
			subject.parseRecipe(item, recipesStr)

		var appropriatingItems = subject.table.getStr("appropriated", line)
		if appropriatingItems != "":
			subject.parseAppropriatingItems(item, appropriatingItems)

	subject.calcRecipeTrees()

	if Game.loadExclusiveContent():
		subject.addCauldronRecipes()

	subject.calcClassAvailability()

	for line in subject.table.countRows() - 1:
		var index = subject.table.getInt("id", line)
		var item = subject.descriptorList[index]

		if not item.isReleased():
			continue

		var classOverride = subject.table.getEnuStuffed("class_override", ItemDescriptor.StuffedClasses, line)
		if classOverride != null:
			item.classes = classOverride

	subject.table = null

	subject.initDescriptionKeys()
	subject.detectMentionedStacks()

	for recipe in subject.forgingHammerDescriptor.recipesAsIngredient:
		var newRecipe = Recipe.new()
		newRecipe.init(recipe.baseItem, [subject.toolboxDescriptor],
			[true], recipe.fusedItem)

	var bloodAmulet = subject.getDescriptor("Blood Amulet")
	var manaOrb = subject.getDescriptor("Mana Orb")
	var holyArmor = subject.getDescriptor("Holy Armor")

	var magicCollar = subject.getDescriptor("Magic Collar")
	var vampiricCollar = subject.getDescriptor("Vampiric Collar")
	var holyCollar = subject.getDescriptor("Holy Collar")

	Recipe.new().init(magicCollar, [bloodAmulet], [true], vampiricCollar)
	Recipe.new().init(holyCollar, [bloodAmulet], [true], vampiricCollar)
	Recipe.new().init(holyCollar, [manaOrb], [true], magicCollar)
	Recipe.new().init(vampiricCollar, [manaOrb], [true], magicCollar)
	Recipe.new().init(magicCollar, [holyArmor], [true], holyCollar)
	Recipe.new().init(vampiricCollar, [holyArmor], [true], holyCollar)

	subject.set_process(false)

static func addCauldronRecipes(subject: Receiver):
	var cauldronDescriptor = subject.getDescriptor("Cauldron")
	for itemName in subject.items:
		var potionDescriptor = subject.items[itemName]
		if potionDescriptor.types[0] == Item.Type.Potion:
			var strongName = "Strong " + itemName
			if strongName in subject.items:

				var strongPotion = subject.items[strongName]
				var recipe = Recipe.new().init(
					potionDescriptor, [cauldronDescriptor], [true], strongPotion)

static func calcClassAvailability(subject: Receiver):

	var craftingDepthBuckets = []
	for itemName in subject.items:
		var descriptor = subject.items[itemName]
		var depth = descriptor.getCraftingDepth()
		if craftingDepthBuckets.size() - 1 < depth:
			craftingDepthBuckets.resize(depth + 1)

		if craftingDepthBuckets[depth] == null:
			craftingDepthBuckets[depth] = []
		craftingDepthBuckets[depth].push_back(descriptor)

	for i in craftingDepthBuckets.size():
		for descriptor in craftingDepthBuckets[i]:
			descriptor.calcClassAvailability()

	for itemName in subject.items:
		var descriptor = subject.items[itemName]
		if subject.canBeGifted(descriptor):
			descriptor.addAppropriatingItem(subject.presentDescriptor)
			descriptor.addAppropriatingItem(subject.rainbowBadgeDescriptor)
			descriptor.addAppropriatingItem(subject.stableRecombobulatorDescriptor)
			descriptor.addAppropriatingItem(subject.bagOfGivingDescriptor)

		for classI in Game.Classes_Full.size():
			if descriptor.isAvailableFor(classI):
				if subject.classBadges[classI] != null:
					descriptor.addAppropriatingItem(subject.classBadges[classI])

	subject.forgingHammerDescriptor.addAppropriatingItem(subject.rainbowBadgeDescriptor)
	subject.forgingHammerDescriptor.addAppropriatingItem(subject.classBadges[Game.Classes.Berserker])
	subject.forgingHammerDescriptor.addAppropriatingItem(subject.bagOfGivingDescriptor)

	var furciferPrimeDescriptor = subject.getDescriptor("Furcifer Prime")

	for itemName in subject.items:
		var descriptor = subject.items[itemName]
		if descriptor.hasType(Item.Type.Food) and descriptor.rarity <= Item.Rarity.Godly:
			descriptor.addAppropriatingItem(subject.amuletOfFeastingDescriptor)

		if subject.isAppropriatedByDigDeeper(descriptor):
			descriptor.addAppropriatingItem(subject.digDeeperDescriptor)

		if descriptor.isCraftedItem():
			descriptor.addAppropriatingItem(furciferPrimeDescriptor)

	var rainbowPotion = subject.getDescriptor("Rainbow Potion")
	for staff in subject.staffDescriptors:
		staff.addAppropriatingItem(rainbowPotion)

	for i in craftingDepthBuckets.size():
		for descriptor in craftingDepthBuckets[i]:
			descriptor.calcAppropriation()

	subject.call_deferred("ready_deferred")

static func initDescriptionKeys(subject: Receiver):
	for itemName in subject.items:
		var item = subject.items[itemName]
		if item.isGem():
			if itemName.ends_with("Ruby"):
				item.descriptionKey = "Ruby"
			elif itemName.ends_with("Sapphire"):
				item.descriptionKey = "Sapphire"
			elif itemName.ends_with("Emerald"):
				item.descriptionKey = "Emerald"
			elif itemName.ends_with("Topaz"):
				item.descriptionKey = "Topaz"
			elif itemName.ends_with("Amethyst"):
				item.descriptionKey = "Amethyst"

		if item.descriptionKey == "":
			item.descriptionKey = itemName

static func detectMentionedStacks(subject: Receiver):

	var stackCmds = {}
	for stack in Game.stackIdentifiers:
		stackCmds[Game.stackIdentifiers[stack]] = "$" + stack

	var typeCmds = {}
	for type in subject.typesWithIcons:
		typeCmds[type] = "$" + type

	for itemName in subject.items:
		var item = subject.items[itemName]
		var descr = item.getDescription()

		for stack in Game.stackIdentifiers.values():
			if Util.findWholeWord(descr, stackCmds[stack]) != - 1:
				item.mentionedStacks[stack] = true

		for type in subject.typesWithIcons:
			if Util.findWholeWord(descr, typeCmds[type]) != - 1:
				item.mentionedTypes[Item.Type[type]] = true

		item.hasBattleRageEffect = (descr.find("$rage[") != - 1)

static func getOnScreenUniques(subject: Receiver, withShop):
	var uniques = {}
	for item in Game.PLAYER.INVENTORY.getItemsAndGems():
		if item.descriptor.randomUniquePool:
			uniques[item.descriptor] = 1

	for item in Game.STORAGEBOX.getItemsAndGems():
		if item.descriptor.randomUniquePool:
			uniques[item.descriptor] = 1

	if Game.draggedItem and Game.draggedItem.descriptor.randomUniquePool:
		uniques[Game.draggedItem.descriptor] = 1

	if withShop:
		for item in Game.shopSceneNode.getItemsNoNull():
			if item.descriptor.randomUniquePool:
				uniques[item.descriptor] = 1

	return uniques

static func getMaxUniques(subject: Receiver) -> int:
	var uniques = 1
	uniques += subject.countItemsInInventoryOfType(subject.platinCardDescriptor)
	if subject.isItemInInventory(subject.uniquelyUniqueDescriptor):
		uniques += int(subject.uniquelyUniqueDescriptor.getP("uniquest"))
	if subject.isItemInInventory(subject.fedoraDescriptor):
		uniques += int(subject.fedoraDescriptor.getP("uniquest"))

	if CustomRules.customRulesActive:
		uniques += CustomRules.getRuleValue(CustomRules.Rules.TreasureLimit)
	return uniques

static func canBeGenerated(subject: Receiver, descriptor: ItemDescriptor, filters: int) -> bool:

	if not (filters & subject.Filter.IgnoreWeight):
		var weight = descriptor.getThresholdWeight(subject.itemCounter)

		if weight < 1 and not Util.flip(weight):

			return false

	if descriptor.isTransient():
		return false

	if descriptor.rarity == Item.Rarity.Unique:

		return false

	if not (filters & subject.Filter.AnyRarity):
		if Game.shopSceneNode.getRarityOddsForCurRound()[descriptor.rarity] <= 0:
			return false

	if filters & subject.Filter.OtherClasses:
		var ok = false
		for classI in Game.getNumClasses():
			if Game.isClassUnlocked(classI) and descriptor.isAvailableFor(classI):
				ok = true
				break
		if not ok:
			return false
	else:
		if not subject.isAvailableForClasses(descriptor):
			return false

	if filters & subject.Filter.OnlyCrafted:
		if not descriptor.isCraftedItem():
			return false
	elif not (filters & subject.Filter.Crafted):
		if descriptor.isCraftedItem():
			if not (descriptor.isGem() and filters & subject.Filter.Gems):
				return false

	if not (filters & subject.Filter.Gated):
		if descriptor.isGatedItem():

			if not subject.isItemOwned(descriptor.gateItem):

				if descriptor in subject.amulets:
					if ( not (filters & subject.Filter.Amulets)):
						return false
				else:
					return false
	else:

		if descriptor.hasType(Item.Type.Card) and not subject.isItemOnScreen(subject.deckOfCardsDescriptor):
			return false
		if descriptor.hasType(Item.Type.ChessPiece) and not subject.isItemOnScreen(subject.chessboardDescriptor):
			return false

	if descriptor.canOnlyExistOnce():
		if subject.isItemOnScreen(descriptor) or subject.isItemStashed(descriptor):
			return false

	if descriptor in subject.spiritCompanionDescriptors:
		if not subject.canHaveMoreCompanions():
			return false

	return true

static func cleanOwnableItems(subject: Receiver):
	for descriptor in subject.ownableItems:
		for item in subject.ownableItems[descriptor]:
			if not is_instance_valid(item) or item == null:
				print(descriptor.getName(), " leftover null instance")
				subject.ownableItems[descriptor].erase(item)
				if subject.ownableItems[descriptor].is_empty():
					subject.ownableItems.erase(descriptor)
				return

static func printOwnableItems(subject: Receiver):
	print("OWNABLE ITEMS")
	for descriptor in subject.ownableItems:
		print(descriptor.getName(), ": ", subject.ownableItems[descriptor].size())
		if descriptor.getName() == "Stone":
			for item in subject.ownableItems[descriptor]:
				print("Stone owner: ", Util.enumToString(Item.Owner, item.ownerType))

static func updateClass(subject: Receiver, triggeringItem):
	var check = true
	if triggeringItem:
		check = false
		if (triggeringItem.ownerType == Item.Owner.PlayerInventory or
			(triggeringItem.ownerType == Item.Owner.PlayerStorageBox and
				triggeringItem.descriptor == subject.stoneBadgeDescriptor)):
			check = true

	if not check: return

	subject.curShopItems.clear()

	subject.curShopClasses = ItemDescriptor.stuffClassIndex(Game.curClass)
	for item in subject.getOwnedItems():
		if item.ownerType == Item.Owner.PlayerInventory:
			for classI in subject.classBadges:
				if item.descriptor == subject.classBadges[classI]:
					subject.curShopClasses |= ItemDescriptor.stuffClassIndex(classI)
					break
			if item.descriptor == subject.rainbowBadgeDescriptor or item.descriptor == subject.bagOfGivingDescriptor:
				subject.curShopClasses |= ItemDescriptor.StuffedClasses.Neutral
		if item.descriptor == subject.stoneBadgeDescriptor:
			subject.curShopClasses &= ~ ItemDescriptor.stuffClassIndex(Game.curClass)

	for rarity in Item.Rarity:
		subject.curShopItems.push_back([])

	for itemName in subject.items:
		var descriptor = subject.items[itemName]
		if descriptor.isShopItem():
			if subject.isAvailableForClasses(descriptor):
				subject.curShopItems[descriptor.rarity].push_back(descriptor)

static func canGetForgingHammer(subject: Receiver, inventoryDict: Dictionary) -> bool:
	var canAccessBerserkerItems = false

	if Game.curClass == Game.Classes.Berserker:
		canAccessBerserkerItems = not subject.isItemOwned(subject.stoneBadgeDescriptor)
	else:
		canAccessBerserkerItems = (
			subject.classBadges[Game.Classes.Berserker] in inventoryDict or
			subject.rainbowBadgeDescriptor in inventoryDict or
			subject.bagOfGivingDescriptor in inventoryDict)

	if not canAccessBerserkerItems:
		return false

	if subject.isItemOnScreen(subject.forgingHammerDescriptor):
		return false

	if subject.isItemOnScreen(subject.toolboxDescriptor):
		return false

	return true

static func getSkillPool(subject: Receiver) -> Array:
	var skillPool = []
	var roundI = 0 if Game.curRound == Game.SKILL_ROUND1 else 1

	for skill in subject.skills[roundI]:
		if ( not skill in subject.nonGeneratableSkills and
			skill.isAvailableFor(Game.curClass) and
			not subject.isItemOnScreen(skill)):

			if skill.requiredItem == null:
				skillPool.push_back(skill)
			elif (subject.isItemOwnedAndWillNotBeConsumed(skill.requiredItem) or
				skill.requiredItem in Game.itemsBeingCrafted):

				skillPool.push_back(skill)

	return skillPool

static func getRandomSkills(subject: Receiver, num) -> Array:
	var selectedSkills = []
	var skillPool = subject.getSkillPool()
	var weights = Array()
	for item in skillPool:
		var weight = item.getWeight()

		if ( not item.isNeutral() and
			item.classes != ItemDescriptor.stuffClassIndex(Game.curClass) and
			Util.bitIncludes(subject.curShopClasses, item.classes)):
				weight *= subject.DUAL_CLASS_WEIGHT

		weights.push_back(weight)

	for i in num:
		var index = subject.randomItemWeightedBag.rollOnce(weights)
		selectedSkills.push_back(skillPool[index])
		weights.remove_at(index)
		skillPool.remove_at(index)

	return selectedSkills

static func _exit_tree(subject: Receiver):
	subject.prepareQueue.clear()
	for cached_items in subject.preparedItemInstances.values():
		for cached_item in cached_items:
			if is_instance_valid(cached_item) and cached_item.get_parent() == null:
				cached_item.free()
	subject.preparedItemInstances.clear()
	# Recipes and descriptors reference one another. Release their scene data
	# and break those cycles when the catalog leaves the tree at shutdown.
	for descriptor in subject.items.values():
		descriptor.scene = null
		descriptor.animationScene = null
		descriptor.recipes.clear()
		descriptor.recipesAsIngredient.clear()
		descriptor.originatingRecipes.clear()
		descriptor.gateItem = null
		descriptor.gatedItems.clear()
		descriptor.requiredItem = null
		descriptor.appropriatingItems.clear()
		descriptor.baseIngredients = null
		descriptor.recipeTree = null
