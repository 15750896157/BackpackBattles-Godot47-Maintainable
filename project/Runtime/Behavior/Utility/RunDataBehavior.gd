extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/RunData.gd")

static func fromSerialized(subject: Receiver, data: Array):

	if data.size() == subject.NUM_PROPERTIES:
		if null in data:
			Util.eprint("found null in ", data)
			return - 1

		subject.runId = data[0]
		subject.encodedName = data[1]
		subject.rating = data[2]
		subject.playerId = data[3]
		subject.results = data[4]
		subject.characterClass = data[5]
		subject.rounds = data[6]
		subject.entryVersion = data[7]
		var res = subject.checkVersion()

		if res == subject.DeserializeResult.VERSION_OK:
			subject.chibiStyle = data[8]
			subject.skins = data[9]
			return 0

	return - 1

static func deserializeMetadata(subject: Receiver, string: String):
	var bitStream = BitStream.new()
	var res = bitStream.fromGodotString(string)
	if not res:
		Util.eassert(false)
		return subject.DeserializeResult.VERSION_TOO_OLD

	subject.entryVersion += str(bitStream.pull(4)) + "."
	subject.entryVersion += str(bitStream.pull(16)) + "."
	subject.entryVersion += str(bitStream.pull(64))
	var versionRes = subject.checkVersion()

	if versionRes == subject.DeserializeResult.VERSION_OK:
		for i in Game.getMaxNumberOfRounds():
			subject.results.push_back(bitStream.pull(Game.RoundResult.size()))

		var withNewClasses = Util.laterOrEqual(subject.entryVersion, "1.0.0")

		var data = subject.deserializeCharacterData(bitStream, withNewClasses)
		subject.characterClass = data[0]
		subject.loadout = data[1]
		subject.chibiStyle = data[2]
		subject.skins = data[3]

	return versionRes

static func countItems(subject: Receiver, untilRound):
	var itemCounter = []
	itemCounter.resize(ItemBook.getNumItems())
	itemCounter.fill(0)
	for roundI in untilRound:
		var roundData = subject.deserializeRound(roundI)
		if roundData == null:
			return null
		for itemData in roundData["items"]:
			itemCounter[itemData["d"].itemIndex] += 1
	return itemCounter

static func isValid(subject: Receiver, currentRound: int):
	var validity = subject.Validity.Ok
	var numQuestionable = 0

	for roundNum in range(1, subject.getNumRounds() + 1):
		var validity2 = subject.isRoundValid(roundNum, currentRound)
		if validity2 == subject.Validity.Invalid:
			Util.eprint("Run invalid 1")
			return subject.Validity.Invalid
		elif validity2 == subject.Validity.Questionable:
			if roundNum == currentRound:
				Util.eprint("Run invalid 2")
				return subject.Validity.Invalid
			numQuestionable += 1

	var questionableRate = numQuestionable / float(subject.getNumRounds())
	Util.eprint("questionableRate: ", questionableRate)
	if questionableRate > 0.3:
		Util.eprint("Run invalid 3")
		return subject.Validity.Invalid

	return validity

static func isRoundValid(subject: Receiver, roundNum: int, currentRound: int):
	var validity = subject.Validity.Ok

	if not Game.isClassUnlocked(subject.characterClass):
		Util.eprint("Encountered sus run. 5")
		return subject.Validity.Invalid

	var roundData = subject.deserializeRound(roundNum)

	if not roundData:
		Util.eprint("Encountered sus run. 6")
		return subject.Validity.Invalid

	if roundData["health"] != Game.getMaxHealthInRound(roundData["class"], roundNum):
		Util.eprint("Encountered sus run. 1")

		return subject.Validity.Invalid

	if roundData["stamina"] > 20:
		Util.eprint("Encountered sus run. 2")
		return subject.Validity.Invalid

	var numUniques = 0
	var uniqueLimit = 1
	uniqueLimit += subject.countDescriptor(roundData["items"], ItemBook.platinCardDescriptor)
	uniqueLimit += subject.countDescriptor(roundData["items"], ItemBook.uniquelyUniqueDescriptor) * ItemBook.uniquelyUniqueDescriptor.getP("uniquest")
	var ownUniques = ItemBook.getNumInventoryUniques()
	var numSubclassUniques = 0
	var bonusStamina = 0
	var numRarity = [0, 0, 0]

	var itemCounter = subject.countItems(roundNum)
	if itemCounter == null:
		Util.eprint("Encountered sus run. 11")
		return subject.Validity.Invalid

	subject.inventoryPrice = 0
	for itemTuple in roundData["items"]:
		var descriptor = itemTuple["d"]
		if not subject.isAvailableForClassOrAppropriated(descriptor, itemCounter):

			Util.eprint(descriptor.getName(), " illegal for class ", Game.getClassName(subject.characterClass))
			Util.eprint("Encountered sus run. 4")
			return subject.Validity.Invalid

		if descriptor.canOnlyExistOnce():
			if subject.countDescriptor(roundData["items"], descriptor) > 1:
				Util.eprint("Encountered sus run. 9")
				return subject.Validity.Invalid

		if descriptor.getRarity() == Item.Rarity.Unique:
			if subject.countDescriptor(roundData["items"], descriptor) > 1:
				Util.eprint("Encountered sus run. 9b")
				return subject.Validity.Invalid

		if not Game.BETA:
			if descriptor.randomUniquePool:
				numUniques += 1
				if numUniques > uniqueLimit:
					Util.eprint("Encountered sus run. 7")
					return subject.Validity.Invalid
				elif currentRound == roundNum:
					if numUniques >= 1 and ownUniques == 0 and Util.flip(0.5):
						Util.eprint("Encountered sus run. 7c")
						validity = subject.Validity.Questionable

		if descriptor.isSubclassItem():
			numSubclassUniques += 1

			if numSubclassUniques > 0 and roundNum < Game.SUBCLASS_ROUND:
				Util.eprint("Encountered sus run. 12")
				return subject.Validity.Invalid
			elif numSubclassUniques > 1:
				Util.eprint("Encountered sus run. 12b")
				return subject.Validity.Invalid

		if ((descriptor.rarity == Item.Rarity.Epic or
			descriptor.rarity == Item.Rarity.Legendary or
			descriptor.rarity == Item.Rarity.Godly) and
			roundNum < subject.raritiesPerRound.size()):

			var offsetRarity = descriptor.rarity - Item.Rarity.Epic
			numRarity[offsetRarity] += 1

		if descriptor.identifier == "Stamina Sack":
			bonusStamina += 1

		subject.inventoryPrice += descriptor.price

		if "g" in itemTuple:
			for gemIndex in itemTuple["g"]:
				if gemIndex >= ItemBook.getNumGems() and gemIndex != RunDatabase.emptySocketId:
					Util.eprint("Encountered sus run. 13")
					return subject.Validity.Invalid
				if gemIndex != RunDatabase.emptySocketId:
					var gemDescriptor = ItemBook.getGemForIndex(gemIndex)
					if not subject.isAvailableForClassOrAppropriated(gemDescriptor, itemCounter):
						Util.eprint("Encountered sus run. 4g")
						return subject.Validity.Invalid
					if gemDescriptor.randomUniquePool:
						numUniques += 1
						if numUniques > uniqueLimit:
							Util.eprint("Encountered sus run. 7b")
							return subject.Validity.Invalid
						elif numUniques == 1 and ownUniques == 0:
							if Util.flip(0.6):
								validity = subject.Validity.TooManyUniques
					subject.inventoryPrice += gemDescriptor.price

	subject.goldInRound = 0
	subject.goldInRound = Game.getGainedGold(roundData["class"], roundNum)

	if roundNum == 1:
		subject.goldInRound *= subject.GOLD_SUS_FACTOR1
	elif roundNum <= 3:
		subject.goldInRound *= subject.GOLD_SUS_FACTOR2
	else:
		subject.goldInRound *= subject.GOLD_SUS_FACTOR3

	if subject.loadout == Game.Loadout.RandomLoadout or Game.Loadout.RandomCharacter:
		subject.goldInRound += max(Game.getStartInventoryPrice(roundData["class"], Game.Loadout.Loadout1),
									Game.getStartInventoryPrice(roundData["class"], Game.Loadout.Loadout2))
		subject.goldInRound += 2

	else:
		subject.goldInRound += Game.getStartInventoryPrice(roundData["class"], subject.loadout)

	var lowerBound = subject.goldInRound * subject.GOLD_LOW_FACTOR
	var upperBound = subject.goldInRound * subject.GOLD_INVALID_FACTOR

	subject.goldInRound = floor(subject.goldInRound)

	if subject.inventoryPrice > upperBound:
		Util.eprint("Encountered sus run. 3c round ", currentRound)
		return subject.Validity.Invalid
	if subject.inventoryPrice > subject.goldInRound:
		Util.eprint("Encountered sus run. 3")
		validity = subject.Validity.Questionable
	elif subject.inventoryPrice < lowerBound:
		Util.eprint("Encountered sus run. 3b")
		validity = subject.Validity.Questionable

	if roundNum < subject.raritiesPerRound.size():
		for rarity in subject.raritiesPerRound[0].size():
			if numRarity[rarity] > subject.raritiesPerRound[roundNum - 1][rarity]:
				Util.eprint("Encountered sus run. 10 in round " + str(roundNum))
				validity = subject.Validity.Questionable

	if 5 + bonusStamina != roundData["stamina"]:
		Util.eprint("Encountered sus run. 2b")

		return subject.Validity.Invalid

	return validity

static func fromData(subject: Receiver, playername, run: Dictionary, lobbyMode: bool):
	subject.encodedName = playername

	var metaData = run.get(subject.VERSION_FIELD)
	if not metaData:
		return subject.DeserializeResult.VERSION_TOO_OLD

	var res = subject.deserializeMetadata(metaData)
	if res != subject.DeserializeResult.VERSION_OK:
		return res

	subject.rating = run.get("r", - 1000)

	subject.playerId = run.get("id", "")

	subject.parseRounds(run)

	return subject.DeserializeResult.VERSION_OK

static func serializeCharacterData(addToBitstream: BitStream, withNewClasses: bool) -> void :

	if withNewClasses:
		addToBitstream.push(Game.curClass, Game.Classes_Full.size())
	else:
		addToBitstream.push(Game.curClass, Game.Classes.size())

	var _loadout = Game.curLoadout
	if Game.randomCharacter:
		_loadout = Game.Loadout.RandomCharacter
	addToBitstream.push(_loadout, Game.Loadout.size())

	addToBitstream.push(int(Game.getChibiMode()), 2)
	for slot in Game.SkinSlot.size():
		addToBitstream.push(Game.getSelectedSkin(slot), SkinBook.MAX_SKINS)

static func deserializeCharacterData(bitStream, withNewClasses: bool):
	var _characterClass
	if withNewClasses:
		_characterClass = bitStream.pull(Game.Classes_Full.size())
	else:
		_characterClass = bitStream.pull(Game.Classes.size())
	var _loadout = bitStream.pull(Game.Loadout.size())
	var _chibi = bool(bitStream.pull(2))
	var _skins = []
	for slot in Game.SkinSlot.size():
		_skins.push_back(bitStream.pull(SkinBook.MAX_SKINS))

	return [_characterClass, _loadout, _chibi, _skins]

static func deserializeItems(metadataString: String, version):
	var bitStream = BitStream.new()
	var res = bitStream.fromGodotString(metadataString)
	if not res:
		if Game.EDITOR:
			assert (false)
		return null

	return Receiver.deserializeStream(bitStream, version)

static func createRoundDict(metadataString: String, _characterClass, _loadout, _name, _chibiStyle, _skins, version, nameIsEncoded: bool):

	var roundData = Receiver.deserializeItems(metadataString, version)
	if roundData == null:
		return null

	if roundData:
		roundData["class"] = _characterClass
		roundData["loadout"] = _loadout
		var decodedName
		if nameIsEncoded:
			decodedName = Util.sharedBitstream.deserializeString(_name)
		else:
			decodedName = _name
		roundData["name"] = Game.limitName(decodedName)
		roundData["chibi"] = _chibiStyle
		roundData["skins"] = _skins
	return roundData

static func deserializeStream(bitStream: BitStream, version):

	var roundData = Dictionary()

	var health = bitStream.pull(Game.MAX_HEALTH)
	if health == - 1:
		return null
	roundData["health"] = health

	var stamina = bitStream.pull(Game.MAX_STAMINA)
	if stamina == - 1:
		return null
	roundData["stamina"] = stamina

	var totalNumItems: int

	if Util.laterOrEqual(version, "1.1.0"):
		totalNumItems = ItemBook.getNumItems()
	else:
		totalNumItems = 510

	var itemTuples = []
	while bitStream.bitsLeft() >= 8:
		var index = bitStream.pull(totalNumItems)
		if index >= totalNumItems or index == - 1:
			if Game.EDITOR:
				Util.eprint("Invalid item index ", index)
			return null

		var descriptor = ItemBook.getDescriptorFromIndex(index)

		if not descriptor.scene:
			if Game.EDITOR:
				Util.eprint("Invalid item (no scene) ", descriptor.getName())
			return null

		var topLeftCellPos = Vector2(
			bitStream.pull(Game.PLAYER.INVENTORY.MAX_SIZE.x),
			bitStream.pull(Game.PLAYER.INVENTORY.MAX_SIZE.y))
		var faceDirection: int = bitStream.pull(4)

		if topLeftCellPos.x < 0 or topLeftCellPos.y < 0 or faceDirection < 0:
			return null

		var itemData = {}
		itemData["d"] = descriptor
		itemData["c"] = topLeftCellPos
		itemData["f"] = faceDirection

		var numSockets = ItemBook.getNumSockets(index)
		if numSockets > 0:
			var hasGems = bitStream.pull(2)
			if hasGems == 1:
				var gems = []
				for socketI in numSockets:
					var gemIndex = bitStream.pull(RunDatabase.totalNumGems)
					if gemIndex >= ItemBook.getNumGems() and gemIndex != RunDatabase.emptySocketId:
						return null
					gems.push_back(gemIndex)

				itemData["g"] = gems

		var instance = Game.itemLibrary.getInstance(descriptor)
		if instance.has_method("getDataPersistent"):
			var numBits = instance.getDataPersistentBits()

			var dataAsInt = bitStream.pullBitsize(numBits)
			var bitStream2 = BitStream.new()
			bitStream2.pushBitsize(dataAsInt, numBits)
			itemData["pd"] = bitStream2.toGodotString()

		itemTuples.push_back(itemData)

	roundData["items"] = itemTuples

	return roundData
