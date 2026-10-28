extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Game.gd")

static func pause(subject: Receiver, pauseSource: int):
	if subject.isInLobby(): return

	if subject.activePauseSources == subject.PauseSource.Unpaused:
		subject.get_tree().paused = true
		subject.gameSpeedBeforePause = Engine.time_scale
		Engine.time_scale = 1.0

		Sound.setMuffledSound(true)
		if pauseSource != subject.PauseSource.RecipeBook:
			ShaderClock.set_scale(0)
		subject.emit_signal("game_paused")

	if pauseSource == subject.PauseSource.Ad:
		AudioServer.set_bus_mute(Sound.MASTER_BUS, true)

	subject.activePauseSources |= pauseSource

static func globalPosToScreenPos(subject: Receiver, pos) -> Vector2:
	var position: Vector2
	var scaling: Vector2
	var windowAspect = subject.get_window().size.x / float(subject.get_window().size.y)
	if windowAspect <= 16 / 9.0:

		var gameHeight = subject.get_window().size.x / (16 / 9.0)
		var borderTop = (subject.get_window().size.y - gameHeight) / 2.0
		position = Vector2(0, borderTop)
		scaling = Vector2(subject.get_window().size.x, gameHeight) / Vector2(1920, 1080)
	else:

		var gameWidth = subject.get_window().size.y * (16 / 9.0)
		var borderLeft = (subject.get_window().size.x - gameWidth) / 2.0
		position = Vector2(borderLeft, 0)
		scaling = Vector2(gameWidth, subject.get_window().size.y) / Vector2(1920, 1080)

	pos = pos * scaling + position
	pos.x = round(pos.x)
	pos.y = round(pos.y)
	return pos

static func getLastRoundResult(subject: Receiver):
	if Expedition.flow == null or Expedition.flow.run.is_empty() or Expedition.flow.run.logs.is_empty():
		return subject.RoundResult.RunOver
	return subject.RoundResult.Win if int(Expedition.flow.run.logs.back().get("winner", 1)) == 0 else subject.RoundResult.Loss

static func expandPath(subject: Receiver, format: String, steamID, full) -> String:
	var params = {
		"ID": "",
		"build": ""
	}
	if steamID != null:
		params["ID"] = str(steamID) + "/"

	if subject.PLAYTEST:
		params["build"] = "playtest/"
	elif full:
		params["build"] = "full/"

	if subject.BETA:
		params["build"] += "beta/"

	var path = format.format(params)
	if path.begins_with("user://"):
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--qa-save-directory="):
				return argument.trim_prefix("--qa-save-directory=").path_join("legacy").path_join(path.trim_prefix("user://"))
	return path

static func makeBaseDir(subject: Receiver):
	var dir: LegacyDirectory = LegacyDirectory.new()
	var err = dir.make_dir_recursive(subject.getSavePath(subject.baseDir_format))

	err = dir.make_dir(subject.getSavePath(subject.backup_format))

	var sharedDirPath = subject.expandPath(subject.baseDir_format)
	dir.make_dir(sharedDirPath)

	if SteamHelper.is_init() and SteamHelper.isIDValid():
		var oldConfigPath = subject.expandPath(subject.config_format)
		var newConfigPath = subject.expandPath(subject.config_format, SteamHelper.STEAM_ID)

		if subject.FULLVERSION:
			var fullConfigPath = subject.expandPath(subject.config_format, SteamHelper.STEAM_ID, true)
			if not dir.file_exists(fullConfigPath):
				if dir.file_exists(newConfigPath):
					dir.copy(newConfigPath, fullConfigPath)
				elif dir.file_exists(oldConfigPath):
					dir.copy(oldConfigPath, fullConfigPath)
		else:

			if not dir.file_exists(newConfigPath) and dir.file_exists(oldConfigPath):
				dir.copy(oldConfigPath, newConfigPath)

static func getLoadPath(subject: Receiver, format: String, isFile: bool) -> String:
	if SteamHelper.is_init() and SteamHelper.isIDValid():
		var dir: LegacyDirectory = LegacyDirectory.new()

		if subject.FULLVERSION:
			var fullPath = subject.expandPath(format, SteamHelper.STEAM_ID, true)
			if isFile:
				if dir.file_exists(fullPath):
					return fullPath
			else:
				if dir.dir_exists(fullPath):
					return fullPath

		var newPath = subject.expandPath(format, SteamHelper.STEAM_ID)
		if isFile:
			if dir.file_exists(newPath):
				return newPath
		else:
			if dir.dir_exists(newPath):
				return newPath

	# Offline recovery writes full-version saves without a Steam account ID.
	if ProjectSettings.get_setting("application/config/recovered_offline"):
		var localPath = subject.expandPath(format, null, subject.FULLVERSION)
		var localDir = LegacyDirectory.new()
		if (isFile and localDir.file_exists(localPath)) or (not isFile and localDir.dir_exists(localPath)):
			return localPath
	var oldPath = subject.expandPath(format, null)
	return oldPath

static func actuallySaveGame(subject: Receiver):

	subject.gameSaveQueued = false
	subject.persistent["version"] = subject.VERSION

	var savePath = subject.getSavePath(subject.savefile_format)

	var dir: LegacyDirectory = LegacyDirectory.new()
	if dir.file_exists(savePath):
		var backupNumbers = subject.findBackups(false)
		var index = 1
		if not backupNumbers.is_empty():
			index = backupNumbers[0] + 1

		var backupFilePath = subject.createBackupFilePath(index)
		dir.rename(savePath, backupFilePath)

		var numExisting = backupNumbers.size()
		var filesToDelete = numExisting - 5
		for i in filesToDelete:
			dir.remove(subject.createBackupFilePath(backupNumbers[numExisting - 1 - i]))

	subject.persistent.erase("cs")
	var dictHash = Util.hashDictionary(subject.persistent)

	subject.persistent["cs"] = dictHash

	Util.writeVarToFile(savePath, subject.persistent)

	if SteamHelper.is_init():
		var offlinePath = subject.getSavePath(subject.offlinesave_format)
		dir.copy(savePath, offlinePath)

static func findBackups(subject: Receiver, isLoad: bool):
	var numbers = []

	var dir: LegacyDirectory = LegacyDirectory.new()
	var backupDir: String
	if isLoad:
		backupDir = subject.getLoadPath(subject.backup_format, false)
	else:
		backupDir = subject.getSavePath(subject.backup_format)

	if dir.open(backupDir) == OK:
		var files = []
		var directories = []
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		Util.addDirectoryContents(dir, files, directories)
		for file in files:
			var fileName = file.get_file()
			var number = int(fileName)

			numbers.push_back(number)

		numbers.sort()
		numbers.reverse()

	return numbers

static func loadGame(subject: Receiver):

	var defaultFileData = subject.getFileContent(subject.getLoadPath(subject.savefile_format))
	if typeof(defaultFileData) == TYPE_DICTIONARY:
		subject.persistent = defaultFileData
	else:
		var backupFiles = subject.createBackupFilePaths(subject.findBackups(true))
		for backupFileName in backupFiles:
			var fileData = subject.getFileContent(backupFileName)
			if typeof(fileData) == TYPE_DICTIONARY:
				print("Successfully loaded from backup: ", backupFileName.get_file())
				subject.persistent = fileData
				break

	if SteamHelper.is_init() and subject.persistent.is_empty():
		var offlineFileData = subject.getFileContent(subject.getLoadPath(subject.offlinesave_format))
		if typeof(offlineFileData) == TYPE_DICTIONARY:
			subject.persistent = offlineFileData
			print("load from offline")

	if not subject.persistent.is_empty() and subject.persistent["version"] == subject.VERSION:
		var cs = subject.persistent["cs"]
		subject.persistent.erase("cs")
		var new_cs = Util.hashDictionary(subject.persistent)
		if cs != new_cs:
			subject.persistent.clear()
			subject.initPlayer()

	subject.initPlayer()

	if subject.steamAvailable:
		if subject.persistent["id"] == 0:
			subject.persistent["id"] = SteamHelper.STEAM_ID
		elif subject.persistent["id"] != SteamHelper.STEAM_ID:
			subject.persistent.clear()
			subject.initPlayer()

	if not subject.isWeb:
		subject.calcTempPath()

	if ("version" in subject.persistent and
		subject.versionToInt(subject.persistent["version"]) < subject.versionToInt("1.1.0") and
		subject.hasPlayedInSeason("2")):
		for classI in 6:
			var rating = subject.getRunRating(classI, "2")
			var leagueExact = subject.getLeague_exact(rating)
			var newLeagueExact = max((leagueExact - 0.5) * 0.9, 0.0)
			subject.setRating(subject.getRatingFromLeague(newLeagueExact), classI)
