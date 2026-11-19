extends "res://Runtime/Compatibility/GameState.gd"

## Profile, legacy saves, localization, class and appearance APIs.

const ClassRegistry = preload("res://PvE/ClassRegistry.gd")

func versionToInt(ver: String = VERSION) -> int:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").versionToInt(self, ver)

func versionToString(ver: int) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").versionToString(self, ver)

func loadExclusiveContent() -> bool:
	return PLAYTEST or FULLVERSION or EDITOR

func showExclusiveContent() -> bool:
	return PLAYTEST or FULLVERSION or EDITOR

func loadUnreleasedClasses() -> bool:
	return FULLVERSION and (EDITOR or PLAYTEST or ENGINEER_TEST)

func loadUnreleasedContent() -> bool:
	return FULLVERSION and (EDITOR or PLAYTEST or ENGINEER_TEST)

func getClassEnum() -> Dictionary:
	if FULLVERSION:
		return Classes_Full
	else:
		return Classes

func getClassKeys() -> Array:
	return getClassEnum().keys()

func getNumClasses() -> int:
	return getClassEnum().size()

func isInLobby() -> bool:
	return RunDatabase.lobbies.isInLobby()

func getEffectiveMode() -> int:
	if curMode == Mode.History:
		return curHistoryData.mode
	else:
		return curMode

func isRankedSwitchMode() -> bool:
	return CustomRules.isRankedSwitchMode() and curMode == Mode.Unranked

func getMaxNumberOfRounds():
	return MAX_ROUNDS

func getLastRoundResult():
	return load("res://Runtime/Behavior/Game/Session.gd").getLastRoundResult(self)

func getTries():
	return int(ceil(float(Expedition.flow.run.health))) if Expedition.active else 0

func giveTry():
	if tries < MAX_TRIES:
		tries += 1

func isSurvivalMode():
	return survivalMode

func canStartSurvivalMode():
	return ( not isSurvivalMode() and
			isArenaMode() and
			wins == MAX_WINS)

func startSurvivalMode():
	survivalMode = true
	justStartedSurvivalMode = true
	giveTry()

func wasPerfectRunBeforeSurvival():
	for i in MAX_WINS:
		if roundResults[i] != RoundResult.Win:
			return false
	return true

func getRoundsToSurvive():
	return MAX_ROUNDS + 1 - curRound

func getTrophies():
	return persistent["trophies"]

func giveTrophies(amount):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").giveTrophies(self, amount)

func loseTrophies(amount):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").loseTrophies(self, amount)

func getGainedGold(forClass, untilRound):
	var _gold = classResources[forClass].gold
	for i in range(1, untilRound + 1):
		_gold += getGoldGain(i)
	return _gold

func getGoldGain(inRound):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getGoldGain(self, inRound)

func getMaxHealthInRound(forClass, untilRound):
	var health = classResources[forClass].health
	for i in range(2, untilRound + 1):
		health += getHealthGain(i)

	return health

func getHealthGain(inRound):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getHealthGain(self, inRound)

func getStartInventoryPrice(forClass, loadout = 0):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getStartInventoryPrice(self, forClass, loadout)

func getNumWins():
	return wins

func getNumLosses():
	return losses

func getRoundResults():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRoundResults(self)

func getTotalRerolls():
	return persistent["rerolls"]

func saveGame():
	if not gameSaveQueued:
		gameSaveQueued = true
		call_deferred("actuallySaveGame")

func expandPath(format: String, steamID = null, full = false) -> String:
	return load("res://Runtime/Behavior/Game/Session.gd").expandPath(self, format, steamID, full)

func makeBaseDir():
	return load("res://Runtime/Behavior/Game/Session.gd").makeBaseDir(self)

func getLoadPath(format: String, isFile: bool = true) -> String:
	return load("res://Runtime/Behavior/Game/Session.gd").getLoadPath(self, format, isFile)

func getSavePath(format: String) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSavePath(self, format)

func actuallySaveGame():
	return load("res://Runtime/Behavior/Game/Session.gd").actuallySaveGame(self)

func findBackups(isLoad: bool):
	return load("res://Runtime/Behavior/Game/Session.gd").findBackups(self, isLoad)

func createBackupFilePath(number):
	var backupPath = getSavePath(backup_format)
	return backupPath.path_join("backup_" + str(number) + ".save")

func createBackupFilePaths(backupNumbers):
	var backupFileNames = []

	for number in backupNumbers:

		var fileName = createBackupFilePath(number)
		backupFileNames.push_back(fileName)
	return backupFileNames

func loadGame():
	return load("res://Runtime/Behavior/Game/Session.gd").loadGame(self)

func getFileContent(path):
	return load("res://Runtime/Behavior/Game/RunFlow.gd").getFileContent(self, path)

func setPatchNoteVersion(version):
	persistent["patchNotesVersion"] = version

func getPatchNoteVersion():
	return persistent["patchNotesVersion"]

func calcTempPath():
	return load("res://Runtime/Behavior/Game/RunFlow.gd").calcTempPath(self)

func getRunStateTmpPath(mode: int = curMode):
	if mode == Mode.Lobbies:
		return tempPath_lobbies
	else:
		return tempPath

func getRunStateFormat(mode: int = curMode):
	if mode == Mode.Lobbies:
		return lobby_runstate_format
	else:
		return runstate_format

func getRunState(mode: int = curMode):
	if mode == Mode.Lobbies:
		return lobbyRunState
	else:
		return arenaRunState

func setRunState(runState, mode: int = curMode):
	if mode == Mode.Lobbies:
		lobbyRunState = runState
	else:
		arenaRunState = runState

func wasRunContinued() -> bool:
	return continueState != ContinueState.NotContinued

func deleteRunStateAndRules(mode: int = curMode):
	CustomRules.reset()
	deleteRunState(mode)

func deleteRunState(mode: int = curMode):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").deleteRunState(self, mode)

func loadRunStateFromPath(path, mode) -> int:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").loadRunStateFromPath(self, path, mode)

func validateRun(mode: int) -> bool:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").validateRun(self, mode)

func loadRunState(mode: int, instanceRunState: bool = true) -> bool:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").loadRunState(self, mode, instanceRunState)

func checkItemsValid(items: Array) -> bool:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").checkItemsValid(self, items)

func isArenaMode(mode = curMode) -> bool:
	return mode == Mode.Unranked or mode == Mode.Ranked

func hasArenaRunState() -> bool:
	return not arenaRunState.is_empty()

func restoreCustomRules(runState):
	var customRules = runState.get("custom", null)
	if customRules != null:
		CustomRules.fromString(customRules)

func defaultPersistentVar(varName, defaultVal):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").defaultPersistentVar(self, varName, defaultVal)

func limitName(_name: String) -> String:
	return _name.left(MAX_NAME_LEN)

func setPlayerName(_name: String):
	persistent["name"] = _name

func getPlayerName() -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getPlayerName(self)

func getSavestateVersion():
	return persistent.get("version", null)

func getNumStartedRuns():
	return persistent["runsStarted"]

func getRunWins():
	return persistent["runWins"]

func getPlayerIdentifier():
	return persistent["identifier"]

func getClassInternalName(charClass = curClass) -> String:
	return getClassKeys()[charClass]

func getSubclass():
	return ""

func getClassOrSubclass() -> String:
	var className = getSubclass()
	if className == "":
		className = getClassInternalName()
	return className

func getClassOrSubclassTranslationKey() -> String:
	var subclass = getSubclass()
	if subclass != "":
		return "SUBCLASS_" + subclass + "_NAME"
	else:
		return getClassTranslationKey()

func getClassTranslationKey() -> String:
	return getClassInternalName() + "_NAME"

func getClassName(charClass = curClass) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getClassName(self, charClass)

func getPveClassDescription(charClass = curClass) -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getPveClassDescription(self, charClass)

func getNativeClassColor(charClass = curClass) -> Color:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getNativeClassColor(self, charClass)

func getTranslatedSubclassName(subclassName) -> String:
	return Util.tra("SUBCLASS_" + subclassName + "_NAME")

func isClassUnlocked(charClass = curClass) -> bool:
	return charClass in ClassRegistry.enabled_indices()

func isClassUnlockedStuffed(charClass: int) -> bool:
	return isClassUnlocked(Util.log2(charClass))

func isClassSelected(charClass) -> bool:

	return charClass == curClass

func getSeason() -> String:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSeason(self)

func getSelectedClass() -> int:
	var selectedClass = persistent["selectedClass"]
	if not isClassUnlocked(selectedClass):
		selectedClass = Classes_Full.Berserker if Expedition.enabled else Classes.Ranger
	return selectedClass

func setLoadout(loadout: int):
	curLoadout = clampi(loadout, 0, 1)
	Expedition.setup_loadout = curLoadout
	emit_signal("loadout_changed")
	return

func getConfiguredLoadout() -> int:
	return clampi(Expedition.setup_loadout, 0, 1)

func getClassesForRandom() -> Array:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getClassesForRandom(self)

func getLeague_exact(rating) -> float:
	return load("res://Runtime/Behavior/Game/RunFlow.gd").getLeague_exact(self, rating)

func getRatingFromLeague(leagueExact: float) -> float:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRatingFromLeague(self, leagueExact)

func getRatingDifference(leagueExact1: float, leagueExact2: float) -> float:
	return getRatingFromLeague(leagueExact1) - getRatingFromLeague(leagueExact2)

func getRatingDifference_forBonus(rating: float, leagueExact2: float) -> float:
	return getRatingFromLeague(leagueExact2) - rating

func getRanking(charClass) -> int:
	return int(getLeagueProgress(charClass) * 100)

func getLeague(charClass) -> int:
	return int(getLeague_exact(getPlayerRating(charClass)))

func getLeagueProgress(charClass) -> float:
	return fmod(getLeague_exact(getPlayerRating(charClass)), 1.0)

func getLeagueName(league):
	return Util.tra("LEAGUE_" + Leagues.keys()[league])

func isBelowLeague(league):
	return getLeague(curClass) < league

func isAtLeastInLeague(league):
	return getLeague(curClass) >= league

func getRankingDifForStats(classI, numWins: int, numLosses: int,
	numTriesLeft: int, survival: bool):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRankingDifForStats(self, classI, numWins, numLosses, numTriesLeft, survival)

func getRankingDifIfConceded():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getRankingDifIfConceded(self)

func getRankingDif_noSurvival():
	return getRankingDifForStats(curClass, wins, losses, tries, false)

func getRankingDif_survival_worst():
	var maxLosses = MAX_TRIES
	if tries < MAX_TRIES:
		maxLosses += 1
	return getRankingDifForStats(curClass, wins, maxLosses, 0, true)

func getRankingDif_survival_best():
	var healedTries = tries
	if tries < MAX_TRIES:
		healedTries += 1
	return getRankingDifForStats(curClass, MAX_ROUNDS - losses, losses, healedTries, true)

func getSwitchModeRating():
	return persistent["smr"]

func setSwitchModeRating(rating):
	persistent["smr"] = rating

func calcRunRatingForClass(classI = curClass, numWins = wins, numLosses = losses,
	triesLeft = tries, survival = survivalMode,
	perfectRunBeforeSurvival = wasPerfectRunBeforeSurvival()):

	var curRating = getPlayerRating(classI)

	return calcRunRating(curRating, numWins, numLosses, triesLeft, survival,
		perfectRunBeforeSurvival)

func calcRunRating(curRating, numWins = wins, numLosses = losses,
	triesLeft = tries, survival = survivalMode,
	perfectRunBeforeSurvival = wasPerfectRunBeforeSurvival()):
	return load("res://Runtime/Behavior/Game/Presentation.gd").calcRunRating(self, curRating, numWins, numLosses, triesLeft, survival, perfectRunBeforeSurvival)

func hasPlayedInSeason(season = getSeason()):
	return "rating" + season in persistent

func getRunRating(charClass, season = getSeason()):
	return persistent["rating" + season][charClass]

func setRating(rating, charClass = curClass):
	persistent["rating" + getSeason()][charClass] = rating

func getPlayerRating(charClass = null):
	if isRankedSwitchMode() or charClass == null:
		return getSwitchModeRating()
	else:
		return getRunRating(charClass)

func wasMaxWins():
	return wins >= MAX_WINS

func wasPerfectRun():
	return wasMaxWins() and losses == 0

func hasSurvived():
	return curRound == MAX_ROUNDS + 1 and tries > 0

func wasPerfectSurvival():
	return hasSurvived() and losses == 0

func getBonusTrophies() -> int:
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getBonusTrophies(self)

func setLocale(locale):
	print("SETTING LOCALE TO ", locale)
	TranslationServer.set_locale(locale)

	Util.updateLocale()
	updateLocale()

func updateLocale():
	var localizedNodes = get_tree().get_nodes_in_group("Localized")
	for node in localizedNodes:
		node.updateLocale()

	itemLibrary.updateSearchDescriptions()

func initLocale():
	setLocale(getConfigValue("Options", "language", getDefaultLocale()))

func setConfigValue(groupName, propertyName, propertyValue):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setConfigValue(self, groupName, propertyName, propertyValue)

func eraseConfigValue(groupName, propertyName):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").eraseConfigValue(self, groupName, propertyName)

func getConfigValue(groupName, propertyName, defaultValue):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getConfigValue(self, groupName, propertyName, defaultValue)

func applySetSkins():
	if not is_instance_valid(PLAYER) or not is_instance_valid(PLAYER.sprite): return
	for slot in SkinSlot.size():
		PLAYER.sprite.setSkin(slot, getSelectedSkin(slot))

func setShowChibis(showChibis):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setShowChibis(self, showChibis)

func getEffectiveChibiMode() -> bool:
	return getChibiMode() and getShowChibis()

func getShowChibis():
	return Settings.getVal(Settings.Setting.opponent_chibis)

func setChibiMode(_chibiMode):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").setChibiMode(self, _chibiMode)

func getChibiMode():
	return chibiMode[curClass]

func getDefaultLocale():
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getDefaultLocale(self)

func getSkinConfigKey(slot: int, charClass = curClass, chibi = getEffectiveChibiMode()):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSkinConfigKey(self, slot, charClass, chibi)

func getSelectedSkin(slot):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSelectedSkin(self, slot)

func selectSkin(slot, skinId):
	var key = getSkinConfigKey(slot)
	setConfigValue("Wardrobe", key, skinId)

func getSkinUnlockKey(slot: int, charClass = curClass, chibi = getEffectiveChibiMode()):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getSkinUnlockKey(self, slot, charClass, chibi)

func isSkinAvailable(skinId: int) -> bool:
	var numSkins = SkinBook.getNumSkinsForClass(curClass, int(getEffectiveChibiMode()))
	return skinId < numSkins

func isSkinUnlocked(slot: int, skinId: int):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").isSkinUnlocked(self, slot, skinId)

func unlockSkin(slot: int, skinId: int):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").unlockSkin(self, slot, skinId)

func getStatisticsKey(statistic: int) -> String:
	return "Stat" + str(statistic)

func getItemStatistics(statistic: int, descriptor: ItemDescriptor, default = null):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").getItemStatistics(self, statistic, descriptor, default)

func setItemStatistic(statistic: int, descriptor: ItemDescriptor, newValue):
	if not ITEM_STATISTICS_ENABLED: return
	var key = getStatisticsKey(statistic)
	persistent[key][descriptor.getIndex()] = newValue

func incrementItemStatistic(statistic: int, descriptor: ItemDescriptor, increment = 1):
	return load("res://Runtime/Behavior/Game/ProgressAndRewards.gd").incrementItemStatistic(self, statistic, descriptor, increment)

func addRecord(statistic: int, descriptor: ItemDescriptor, amount: int = 0):
	return load("res://Runtime/Behavior/Features/Core/GameBehavior.gd").addRecord(self, statistic, descriptor, amount)

func getRecordQueue():
	var runState = getRunState()
	return runState.get("rq", [])

func clearRecordQueue():
	var runState = getRunState()
	runState["rq"] = []
