extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Game.gd")

static func getFileContent(subject: Receiver, path):
	var file = File.new()
	if file.file_exists(path):
		var err = file.open(path, File.READ)
		if err == OK:
			if file.get_length() > 10:
				var data = file.get_var()
				if typeof(data) == TYPE_DICTIONARY:
					return data
				else:
					print("Failed loading file from ", path.get_file())
			file.close()
		else:
			print("Failed loading file from ", path.get_file(), " with error ", err)

	return - 1

static func calcTempPath(subject: Receiver):
	if OS.has_feature("Windows"):
		subject.tempPath = OS.get_environment("temp")

		if OS.get_environment("STEAM_COMPAT_DATA_PATH") != "":
			subject.canCommitRun = false
			print("(1) Proton ", OS.get_environment("STEAM_COMPAT_DATA_PATH"))
		elif OS.get_environment("TMPDIR") != "":
			subject.canCommitRun = false
			print("(2) Proton ", OS.get_environment("TMPDIR"))

		if subject.EXPO: subject.canCommitRun = false

	if subject.tempPath != "":
		subject.loadTemp = true

		subject.tempName = subject.persistent["identifier"]
		if subject.FULLVERSION:
			subject.tempName += "full"
		if subject.PLAYTEST:
			subject.tempName += "playtest"
		elif subject.BETA:
			subject.tempName += "beta"
		var tempName_lobbies = (subject.tempName + "t").md5_text().left(32)
		subject.tempName = subject.tempName.md5_text().left(32)
		var j = 0
		for i in [8, 12, 16, 20]:
			subject.tempName = subject.tempName.insert(i + j, "-")
			tempName_lobbies = tempName_lobbies.insert(i + j, "-")
			j += 1

		subject.tempPath_lobbies = subject.tempPath + "\\" + tempName_lobbies + ".tmp"
		subject.tempPath += "\\" + subject.tempName + ".tmp"

static func loadRunStateFromPath(subject: Receiver, path, mode) -> int:
	var res = subject.RunStateLoadResult.FileCorrupt
	var save_game = File.new()

	if mode == subject.Mode.Lobbies and not ProjectSettings.get_setting("application/config/local_services", false):
		var time = save_game.get_modified_time(path)
		var dif = Time.get_unix_time_from_system() - time
		Util.eprint("file time dif: ", dif)
		if dif > 60 * subject.LOBBY_TIMEOUT_MINUTES or dif < 0:
			print("Lobby state timeout ", dif)
			return subject.RunStateLoadResult.NoRun

	var err = save_game.open(path, File.READ)
	if err == OK:

		if save_game.get_length() > 3:
			var saveData = save_game.get_var()
			if typeof(saveData) == TYPE_DICTIONARY:
				subject.setRunState(saveData, mode)
				res = subject.RunStateLoadResult.LoadedRun
			else:
				print("Runstate loading error!")
		else:
			res = subject.RunStateLoadResult.NoRun
		save_game.close()
	else:
		print("Runstate loading error: ", err)
	return res

static func validateRun(subject: Receiver, mode: int) -> bool:
	var runState = subject.getRunState(mode)

	var version = runState["version"]
	if not Util.laterOrEqual(version, subject.runStateBreakingVersion):
		subject.deleteRunState(mode)
		return false

	var cs = runState["cs"]
	runState.erase("cs")
	if cs != Util.hashDictionary(runState):
		print("Could not load run. 1")
		subject.deleteRunState(mode)
		return false

	if not subject.BETA:
		var sqn = runState["sqn"]
		if typeof(sqn) != TYPE_INT or sqn != SteamHelper.getSequenceNum(mode):
			if SteamHelper.getSequenceNum(mode) == 0:
				print("SQN 0")
			else:
				Util.eprint("load sequence num: ", sqn, " != ", SteamHelper.getSequenceNum(mode))
				print("Could not load run. 2")
				runState.clear()
				return false

	return true

static func loadRunState(subject: Receiver, mode: int, instanceRunState: bool) -> bool:
	var loadedRun = false

	var save_game = File.new()
	var path = subject.getRunStateTmpPath(mode)

	if subject.loadTemp and save_game.file_exists(path):
		var res = subject.loadRunStateFromPath(path, mode)
		if res == subject.RunStateLoadResult.LoadedRun:

			loadedRun = subject.validateRun(mode)

	if not loadedRun:
		path = subject.getLoadPath(subject.getRunStateFormat(mode))

		if save_game.file_exists(path):
			var res = subject.loadRunStateFromPath(path, mode)
			if res == subject.RunStateLoadResult.LoadedRun:
				loadedRun = subject.validateRun(mode)

	if loadedRun:
		var runState = subject.getRunState(mode)

		for key in subject.runStateFields:
			if not key in runState:
				runState.clear()
				return false

		if runState["gold"] < 0:
			runState.clear()
			return false

		var selectedClass = runState["class"]
		if not subject.isClassUnlocked(selectedClass):
			runState.clear()
			return false

		if not subject.checkItemsValid(runState["inventory"]):
			runState.clear()
			return false

		if instanceRunState:
			subject.initPlayerFromRunstate(mode)

			if runState["incombat"]:
				print("incombat runstate")
				runState["results"][runState["round"] - 1] = subject.RoundResult.Loss
				runState["round"] += 1
				runState["tries"] -= 1
				runState["losses"] += 1

			subject.readRoundResultsFromRunState(mode)

			if subject.runOver():
				if mode == subject.Mode.Lobbies:
					subject.endRun_lobby()
				else:
					subject.endRun(false, false)
				return false

	return loadedRun

static func initPlayerFromRunstate(subject: Receiver, mode: int):
	var runState = subject.getRunState(mode)
	if runState.is_empty():
		CustomRules.reset()
		return

	subject.deleteDraggedItem()
	subject.instanceCharacter(runState["class"])
	subject.curLoadout = runState["loadout"]
	subject.randomCharacter = runState.get("randomClass", false)
	subject.restoreCustomRules(runState)
	subject.setGold(runState["gold"])
	subject.PLAYER.setMaxHealth(runState["maxHealth"])
	subject.PLAYER.setMaxStamina(runState["maxStamina"])

	subject.PLAYER.INVENTORY.reset()
	var inventoryState = runState["inventory"]
	for itemData in inventoryState:
		var itemId = itemData[0]
		var descriptor = ItemBook.getDescriptorFromIndex(itemId)
		if not descriptor.scene:
			runState.clear()
			return false
		var item = ItemBook.instantiateItem(descriptor)
		var topLeftCellPos = itemData[1]
		var faceDirection = itemData[2]
		subject.PLAYER.INVENTORY.orientAndAddItem(item, topLeftCellPos, faceDirection)
		item.setData(itemData[3])
		var locked = itemData[4]
		if locked == null: locked = false
		item.setLocked(locked, false)
		if itemData.size() >= 6:
			item.setGemData(itemData[5])

	subject.emit_signal("runstate_loaded")

static func readRoundResultsFromRunState(subject: Receiver, mode: int):
	var runState = subject.getRunState(mode)
	subject.setMode(runState["mode"])
	subject.curRound = runState["round"]
	subject.wins = runState["wins"]
	subject.losses = runState["losses"]
	subject.tries = runState["tries"]
	subject.survivalMode = runState["survival"]
	subject.roundResults = runState["results"].duplicate()

static func concedeLastRun(subject: Receiver):
	if Engine.get_physics_frames() == subject.endRunFrame:
		Util.eassert(false)
		print("Duplicate end run (concede)")
		return

	subject.readRoundResultsFromRunState(subject.Mode.Unselected)
	subject.losses = subject.MAX_TRIES
	subject.tries = 0
	subject.runWasConceded = true
	subject.endRun(false, false)
	subject.curRound = 1
	subject.setMode(subject.Mode.Unselected)
	subject.instanceCharacter(subject.getSelectedClass())
	if subject.LOADOUTS_ENABLED:
		subject.setLoadout(subject.getConfiguredLoadout())
	else:
		subject.setLoadout(0)

static func initPlayer(subject: Receiver):

	subject.defaultPersistentVar("name", "")
	subject.defaultPersistentVar("identifier", Util.generateRandomString(16))

	if subject.FULLVERSION:
		var varName = "rating" + subject.getSeason()
		subject.defaultPersistentVar(varName, {})
		for classI in subject.getNumClasses():
			if not classI in subject.persistent[varName]:
				subject.persistent[varName][classI] = 0.0
	else:
		var ratings = []
		for classI in subject.getNumClasses():
			ratings.push_back(0.0)
		subject.defaultPersistentVar("rating", ratings)

	if subject.ITEM_STATISTICS_ENABLED:
		for statistic in subject.ItemStatistic.values():
			var key = subject.getStatisticsKey(statistic)
			var arr = []
			arr.resize(ItemBook.getNumItems())
			subject.defaultPersistentVar(key, arr)

	subject.defaultPersistentVar("totalWins", 0)
	subject.defaultPersistentVar("trophies", 0)
	subject.defaultPersistentVar("runWins", 0)
	subject.defaultPersistentVar("rerolls", 0)
	subject.defaultPersistentVar("runsStarted", 0)
	subject.defaultPersistentVar("runsFinished", 0)
	subject.defaultPersistentVar("lastRandomClass", - 1)
	subject.defaultPersistentVar("crafted", 0)
	subject.defaultPersistentVar("craftedRecipes", {})
	subject.defaultPersistentVar("selectedClass", subject.Classes.Ranger)
	subject.defaultPersistentVar("unlockedSkins", {})
	subject.defaultPersistentVar("rotations", 0)

	subject.defaultPersistentVar("tutorial", 0)
	subject.defaultPersistentVar("smr", 0.0)

	subject.defaultPersistentVar("id", 0)
	subject.defaultPersistentVar("patchNotesVersion", "0.1.0")

static func getLeague_exact(subject: Receiver, rating) -> float:
	rating = max(0, rating)
	var league = subject.Leagues.ImpossibleWoodRank
	for threshold in subject.leagueThresholds:
		if rating >= threshold:
			league += 1
		else:
			break

	var leftBorder = subject.leagueThresholds[league]
	var rightBorder = subject.leagueThresholds[league + 1]
	var bracketSize: float = rightBorder - leftBorder
	var interpolationPoint = (rating - leftBorder) / bracketSize

	return league + interpolationPoint

static func _enter_tree(subject: Receiver):
	if not subject.isWeb:
		subject.locales["简体中文"] = "zh_Hans_CN"
		subject.locales["日本語"] = "ja"
		subject.locales["한국어"] = "ko"
		subject.locales["Deutsch"] = "de"
		subject.locales["繁體中文"] = "zh_Hant_TW"
		subject.locales["Español latinoamericano"] = "es"
		subject.locales["Français"] = "fr"
		subject.locales["Русский"] = "ru"
		subject.locales["Português Brasileiro"] = "pt_BR"

static func _ready(subject: Receiver) -> void :
	if Expedition.enabled:
		subject.get_tree().auto_accept_quit = false
		subject.call_deferred("_pve_initialize_role_stats")
	subject.process_mode = Node.PROCESS_MODE_ALWAYS
	var main_scene = subject.get_node_or_null("/root/Main")
	if main_scene != null:
		main_scene.tree_exiting.connect(subject._begin_shutdown)

	print("VERSION ", subject.VERSION, subject.SUBVERSION)

	subject.steamAvailable = ( not OS.has_feature("disable_steam_integration")
		and SteamHelper.is_init())

	subject.localeToLanguage = Util.invertDictionary(subject.locales)

	if subject.useShell():
		subject.processTimer = Timer.new()
		subject.add_child(subject.processTimer)
		subject.processTimer.one_shot = true
		subject.processTimer.connect("timeout", Callable(subject, "checkProcesses_cyclic"))

	subject.makeBaseDir()

	if subject.PLAYTEST:
		print("PLAYTEST")
	elif subject.BETA:
		print("BETA")

	subject.randnum = (Util.rng.randi() << 32) + Util.rng.randi()
	subject.gold_internal = subject.encode(0)

	subject.loadGame()

	subject.call_deferred("ready_deferred")

	for league in subject.Leagues:
		var i = subject.Leagues[league]
		if i != - 1:
			subject.leagueIcons.push_back(load("res://Assets/Leagues/League_" + league + ".png"))

	var basePath = "res://CharacterClasses/"
	for className in subject.Classes_Full:
		if subject.isClassUnlocked(subject.Classes_Full[className]):
			subject.classResources.push_back(load(str(basePath, className, "/", className, ".tres")))
		else:
			subject.classResources.push_back(null)

	for classIndex in subject.getNumClasses():
		if subject.isClassUnlocked(classIndex):
			subject.classResources[classIndex].loadFiles(subject.getClassKeys()[classIndex])
		subject.chibiMode.push_back(subject.getConfigValue("Options", "Chibi_" + subject.getClassKeys()[classIndex], false))

	if subject.BUILD_HISTORY_ENABLED:

		subject.buildHistoryDB = load("res://Utility/BuildHistoryDB.gd").new()

	subject.stealLifeDamageSource = DamageSource.new().init(null, DamageSource.Type.Effect)
	subject.stealLifeDamageSource.flags = DamageSource.effectFlags

	subject.unhealingDamageSource = DamageSource.new().init(null, DamageSource.Type.Unhealing)
	subject.unhealingDamageSource.flags = DamageSource.unhealingFlags

	subject.fatigueDamageSource = DamageSource.new().init(subject, DamageSource.Type.Fatigue)
	subject.fatigueDamageSource.flags = DamageSource.Flags.CanBeBlocked

	for argument in OS.get_cmdline_args():
		if argument == "-write_state":
			print("Writing out state.")
			subject.WRITE_OUT_STATE = true

	for c in subject.cursors:
		var c2 = ImageTexture.new()
		var img = Image.new()
		img.copy_from(c)
		c2 = ImageTexture.create_from_image(img)
		subject.scaledCursors.push_back(c2)

	# Local builds use dedicated QA scenes instead of missing legacy debug windows.

static func ready_deferred(subject: Receiver):
	print("OS: ", OS.get_name())
	print("vsync on: ", Settings.getVal(Settings.Setting.vsync))

	var selectedClass = subject.getSelectedClass()
	if Expedition.enabled:
		if selectedClass not in [subject.Classes_Full.Berserker, subject.Classes_Full.Reaper]: selectedClass = subject.Classes_Full.Berserker
		await AssetStream.prepare_actor(selectedClass, Game.getEffectiveChibiMode(), "actor-player", true)
		subject.instanceCharacter(selectedClass)
		subject.sceneAnimation.connect("animation_finished", Callable(subject, "onSceneAnimationFinished"))
		subject.emit_signal("continue_loaded")
		subject.splashScreenAnimation.play("FadeOut")
		subject.sceneAnimation.play("StartOnTitle")
		subject.playerNodeAnimation.play("Start")
		Sound.playBGM(Sound.titleBGM, 0, 0)
		return
	subject.instanceCharacter(selectedClass)

	if is_instance_valid(MaterialCompiler) and not MaterialCompiler.completed:
		await MaterialCompiler.finished_loading_materials

	subject.sceneAnimation.connect("animation_finished", Callable(subject, "onSceneAnimationFinished"))

	subject.loadRunState(subject.Mode.Unranked, false)

	if subject.LOBBIES_ENABLED and subject.loadRunState(subject.Mode.Lobbies):

		RunDatabase.lobbies.connect("lobby_joined", Callable(subject, "onReconnectedToLobby"))
		RunDatabase.lobbies.connect("lobby_join_failed", Callable(subject, "onReconnectTimeout"))
		RunDatabase.lobbies.tryReconnect()

	else:
		subject.deleteRunStateAndRules(subject.Mode.Lobbies)
		subject.loadArenaRunAndStartOnTitle()

static func onReconnectedToLobby(subject: Receiver):
	RunDatabase.lobbies.disconnect("lobby_joined", Callable(subject, "onReconnectedToLobby"))
	RunDatabase.lobbies.disconnect("lobby_join_failed", Callable(subject, "onReconnectTimeout"))
	subject.applySetSkins()
	subject.splashScreenAnimation.play("FadeOut")
	subject.playerNodeAnimation.play("Start")
	subject.continueLastRun(subject.Mode.Lobbies)
	subject.call_deferred("onReconnectedToLobby_deferred")

static func loadArenaRunAndStartOnTitle(subject: Receiver):
	var selectedClass = subject.getSelectedClass()

	if not subject.loadRunState(subject.Mode.Unranked):
		subject.instanceCharacter(selectedClass)
		if subject.LOADOUTS_ENABLED:
			subject.setLoadout(subject.getConfiguredLoadout())
			if subject.getConfigValue("Options", "RandomClass", false):
				subject.randomCharacter = true
		else:
			subject.setLoadout(0)

	subject.applySetSkins()

	subject.emit_signal("continue_loaded")

	subject.splashScreenAnimation.play("FadeOut")
	subject.sceneAnimation.play("StartOnTitle")
	subject.playerNodeAnimation.play("Start")
	Util.callDelayed(Sound, "playSound", 1.5, [subject.playerMoveInSound])
	Sound.playBGM(Sound.titleBGM, 0, 0)

	SteamHelper.updateRichPresence()

static func instanceCharacter(subject: Receiver, characterClass: int):
	if Expedition.enabled:
		Util.killTween(subject.characterTween)
		Util.killTween(subject.loadoutTween)
	var before = subject.curClass
	subject.curClass = characterClass
	if subject.isClassUnlocked() and subject.curMode != subject.Mode.History:
		subject.persistent["selectedClass"] = subject.curClass

	if not subject.PLAYER:
		subject.PLAYER = subject.playerScene.instantiate()
		subject.PLAYER.playerId = subject.PLAYER.ID.PLAYER
		subject.PLAYER.position = Vector2(subject.playerCombatPos, 880)
		subject.playerNode.add_child(subject.PLAYER)
		subject.PLAYER.setCharacterName(subject.getPlayerName())
		subject.PLAYER.connect("character_died", Callable(subject, "endCombat"))
	else:
		subject.PLAYER.INVENTORY.reset()

	subject.PLAYER.setClass(subject.curClass, subject.getEffectiveChibiMode())
	for slot in subject.SkinSlot.values():
		Game.PLAYER.sprite.setSkin(slot, subject.getSelectedSkin(slot))

	if before != subject.curClass:
		Util.finishTween(subject.characterTween)
		subject.characterTween = Util.refreshTween(subject.characterTween)
		var sprite = subject.PLAYER.sprite.get_node("Body")
		var offsetPos1 = sprite.position.y - Util.rng.randf_range(80, 100)
		var offsetPos2 = sprite.position.y - Util.rng.randf_range(10, 20)
		var downDur1 = 0.2
		var upDur = 0.05
		var downDur2 = 0.1
		subject.characterTween.tween_property(sprite, "position:y", sprite.position.y,
			downDur1).from(offsetPos1).set_ease(Tween.EASE_IN)
		subject.characterTween.tween_property(sprite, "position:y", offsetPos2,
			upDur).from(sprite.position.y).set_ease(Tween.EASE_OUT)
		subject.characterTween.tween_property(sprite, "position:y", sprite.position.y,
			downDur2).from(offsetPos2).set_ease(Tween.EASE_IN)

	subject.emit_signal("character_changed")

static func addLoadoutAni_jump(subject: Receiver, bag):
	var upDur = 0.05
	var downDur = 0.15
	var offset = Util.rng.randf_range(20, 50)

	for node in [bag, subject.PLAYER.INVENTORY]:
		var offsetPos = node.position.y - offset
		subject.loadoutTween.tween_property(node, "position:y", offsetPos,
			upDur).set_ease(Tween.EASE_OUT)
		subject.loadoutTween.tween_property(node, "position:y", node.position.y,
			downDur).from(offsetPos).set_delay(upDur).set_ease(Tween.EASE_IN_OUT)

static func addLoadoutAni(subject: Receiver, node, isBag):
	var delay = 0.1

	if isBag:
		delay *= Util.rng.randf_range(0.8, 1.2)
		var downDur = 0.05
		var upDur = 0.1
		var offsetPos = node.position.y + Util.rng.randf_range(5, 15)
		subject.loadoutTween.tween_property(node, "position:y", offsetPos,
			downDur).set_delay(delay).set_ease(Tween.EASE_IN)
		subject.loadoutTween.tween_property(node, "position:y", node.position.y,
			upDur).from(offsetPos).set_delay(downDur + delay).set_ease(Tween.EASE_OUT)
	else:
		delay *= Util.rng.randf_range(0.6, 1.4)
		var upDur = 0.05
		var downDur = 0.05
		var jumpFactor = Util.rng.randf_range(1, 2)
		var startPos: Vector2 = node.position - Vector2(0, 100 * jumpFactor)
		var bouncePos: Vector2 = node.position - Vector2(0, 10 * jumpFactor)
		subject.loadoutTween.tween_property(node, "position", node.position,
			delay).from(startPos).set_ease(Tween.EASE_OUT)

		subject.loadoutTween.tween_property(node, "position", bouncePos,
			upDur).set_delay(upDur + delay)
		subject.loadoutTween.tween_property(node, "position", node.position,
			upDur).set_delay(downDur + upDur + delay).from(bouncePos)

static func startHistoryRun(subject: Receiver, runData, roundNum: int, opponentData, opponentRoundNum):
	subject.setMode(subject.Mode.History)
	subject.curHistoryData = runData
	subject.curRound = roundNum
	subject.wins = subject.curHistoryData.getWins(roundNum - 1)
	subject.losses = subject.curHistoryData.getLosses(roundNum - 1)
	if roundNum == 1:
		subject.tries = subject.MAX_TRIES
	else:
		subject.tries = subject.curHistoryData.getTries(roundNum - 1)

	subject.instanceCharacter(subject.curHistoryData.classI)
	CustomRules.fromString(subject.curHistoryData.customRules)
	var roundData = subject.curHistoryData.getRoundData(roundNum)
	var items = RunData.deserializeItems(roundData.items, subject.curHistoryData.getVersionString())["items"]
	subject.PLAYER.INVENTORY.createFromItemTuples(items, Item.Owner.PlayerInventory)
	subject.PLAYER.setMaxHealth(roundData.health)
	subject.PLAYER.setMaxStamina(roundData.stamina)
	subject.initRoundResults()

	subject.sceneAnimation.play("TitleToShop")
	subject.sceneAnimation.advance(1000)
	subject.sceneAnimation.play("ShopToCombat")
	subject.sceneAnimation.advance(3.5)

	subject.emit_signal("switching_to_combat")
	print("Refighting from history.")

static func endHistoryRun(subject: Receiver):
	if subject.curHistoryData != null:
		subject.curHistoryData = null
		subject.sceneAnimation.play("CombatToTitle")
		subject.sceneAnimation.advance(100)
		subject.sceneAnimation.play("StartOnTitle")
		subject.sceneAnimation.advance(100)
		subject.playerNodeAnimation.play("ReturnToTitle")
		subject.playerNodeAnimation.advance(100)
		subject.combatSceneNode.clearParticles()
		subject.PLAYER.combatToTitle()
		subject.PLAYER.finishAnimations()
		for node in subject.get_tree().get_nodes_in_group("CombatLabel"):
			node.delete()
		for item in subject.OPPONENT.INVENTORY.getItems():
			item.combatToTitle()
		CustomRules.reset()
		subject.returnedToTitle_afterRun()
		subject.emit_signal("combat_scene_left")
		subject.emit_signal("return_to_history")

static func isSoftballRound(subject: Receiver):

	if subject.getRunRating(subject.curClass) > 80:
		return false

	if subject.getNumStartedRuns() == 1:
		return true
	elif subject.getNumStartedRuns() == 2:
		return subject.curRound % 4 != 0
	elif subject.getNumStartedRuns() == 3 or subject.getRunWins() == 0:
		return subject.curRound % 2 != 0
	elif subject.getNumStartedRuns() == 4 or subject.getRunWins() == 1:
		return subject.curRound % 4 == 0
	else:
		return false
