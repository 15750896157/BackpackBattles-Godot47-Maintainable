extends RefCounted
class_name RunData

const NUM_PROPERTIES = 10
var corrupted = false
var runId
var encodedName: String
var rating: float
var playerId: String
var results: Array
var characterClass: int
var loadout: int
var rounds: Array
var entryVersion = ""
var chibiStyle: bool
var skins = []

var mmScore = 0.0

enum DeserializeResult{
	VERSION_TOO_NEW = 0,
	VERSION_TOO_OLD = 1,
	VERSION_OK = 2,
}

enum Validity{
	Ok = 0,
	Questionable = 1,
	Invalid = 2,
	TooManyUniques = 3,
}

func serialize():
	return load("res://Runtime/Behavior/Features/Utility/RunDataBehavior.gd").serialize(self)

func fromSerialized(data: Array):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").fromSerialized(self, data)

func checkVersion():
	return load("res://Runtime/Behavior/Features/Utility/RunDataBehavior.gd").checkVersion(self)

func deserializeMetadata(string: String):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").deserializeMetadata(self, string)

static func serializeCharacterData(addToBitstream: BitStream,
	withNewClasses: bool) -> void :
	load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").serializeCharacterData(addToBitstream, withNewClasses)

static func deserializeCharacterData(bitStream, withNewClasses: bool):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").deserializeCharacterData(bitStream, withNewClasses)

const dictIndex = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17"]

func parseRounds(wholeRun: Dictionary):
	for index in dictIndex:
		if index in wholeRun:
			rounds.push_back(wholeRun[index])
		else:
			break

func deserializeRound(roundIndex):
	return createRoundDict(rounds[roundIndex - 1], characterClass,
		loadout, encodedName, chibiStyle, skins.duplicate(), entryVersion)

func deserializeItemsOfRound(roundIndex):
	return deserializeItems(rounds[roundIndex - 1], entryVersion)

static func deserializeItems(metadataString: String, version):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").deserializeItems(metadataString, version)

func getDecodedName() -> String:
	return Util.sharedBitstream.deserializeString(encodedName)

static func createRoundDict(metadataString: String,
	_characterClass, _loadout, _name, _chibiStyle, _skins,
	version, nameIsEncoded: bool = true):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").createRoundDict(metadataString, _characterClass, _loadout, _name, _chibiStyle, _skins, version, nameIsEncoded)

static func deserializeStream(bitStream: BitStream, version):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").deserializeStream(bitStream, version)

func getNumRounds() -> int:
	return rounds.size()

func getWinsAtRound(roundNum: int) -> int:
	var wins = 0
	for roundI in roundNum:
		if results[roundI] == Game.RoundResult.Win:
			wins += 1
	return wins

func getRoundResult(roundNum: int) -> int:
	return results[roundNum - 1]

func countItems(untilRound):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").countItems(self, untilRound)

func countDescriptor(itemDataArray, descriptor):
	var num = 0
	for itemData in itemDataArray:
		if itemData["d"] == descriptor:
			num += 1

	return num

const GOLD_SUS_FACTOR1 = 0.9
const GOLD_SUS_FACTOR2 = 1.1
const GOLD_SUS_FACTOR3 = 1.25
const GOLD_INVALID_FACTOR = 1.3
const GOLD_LOW_FACTOR = 0.5
var inventoryPrice = 0
var goldInRound = 0

const raritiesPerRound = [
	[0, 0, 0],
	[1, 0, 0],
	[2, 0, 0],
	[99, 1, 0],
	[99, 2, 0],
	[99, 99, 1],
	[99, 99, 2],
]

func isValid(currentRound: int):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").isValid(self, currentRound)

func isAvailableForClassOrAppropriated(descriptor, itemCounter) -> bool:
	return load("res://Runtime/Behavior/Features/Utility/RunDataBehavior.gd").isAvailableForClassOrAppropriated(self, descriptor, itemCounter)

func isRoundValid(roundNum: int, currentRound: int):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").isRoundValid(self, roundNum, currentRound)

func fromSilentWolfScore(score: Dictionary):
	return load("res://Runtime/Behavior/Features/Utility/RunDataBehavior.gd").fromSilentWolfScore(self, score)

func fromSteamScore(dict: Dictionary, lobbyMode: bool):
	return load("res://Runtime/Behavior/Features/Utility/RunDataBehavior.gd").fromSteamScore(self, dict, lobbyMode)

const VERSION_FIELD = "d"
const sharedFields = [VERSION_FIELD, "r", "id", "0", "1", "2", "3", "4"]
const swFields = sharedFields
const steamFields = ["d", "r", "id", "0", "1", "2", "3", "4", "ugc", "p"]

func fromData(playername, run: Dictionary, lobbyMode: bool = false):
	return load("res://Runtime/Behavior/Utility/RunDataBehavior.gd").fromData(self, playername, run, lobbyMode)

