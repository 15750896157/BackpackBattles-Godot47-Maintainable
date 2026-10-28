extends RefCounted
class_name BuildHistoryData

var id: int
var version: int
var time: int

var classI: int
var loadout: int
var mode: int
var customRules: String
var rating: float
var roundHistory: Array = []
var skill1Index = null
var skill2Index = null
var subclassIndex = null

func getVersionString() -> String:
	return Game.versionToString(version)

func addRoundData(roundNum: int, result: int, tries: int,
	health: int, stamina: int, items: String):
	return load("res://Runtime/Behavior/Features/Interface/BuildHistory/BuildHistoryDataBehavior.gd").addRoundData(self, roundNum, result, tries, health, stamina, items)

func isValid() -> bool:
	for roundI in roundHistory.size():
		if roundHistory[roundI] == null:
			return false
	return true

func getRoundData(roundNum: int):
	if roundNum > 0 and roundNum <= roundHistory.size():
		return roundHistory[roundNum - 1]
	else:
		return null

func getWins(upToRound: int = -1) -> int:
	return load("res://Runtime/Behavior/Features/Interface/BuildHistory/BuildHistoryDataBehavior.gd").getWins(self, upToRound)

func getLosses(upToRound: int = -1) -> int:
	return load("res://Runtime/Behavior/Features/Interface/BuildHistory/BuildHistoryDataBehavior.gd").getLosses(self, upToRound)

func getTries(atRound: int = -1) -> int:
	return load("res://Runtime/Behavior/Features/Interface/BuildHistory/BuildHistoryDataBehavior.gd").getTries(self, atRound)

func getSurvivalStartRound() -> int:
	return load("res://Runtime/Behavior/Interface/BuildHistory/BuildHistoryDataBehavior.gd").getSurvivalStartRound(self)

func getRounds() -> int:
	return roundHistory.size()

func getTimeDif() -> Dictionary:
	return load("res://Runtime/Behavior/Features/Interface/BuildHistory/BuildHistoryDataBehavior.gd").getTimeDif(self)

class RoundData:
	extends RefCounted
	var result: int
	var tries: int
	var health: int
	var stamina: int
	var items: String
