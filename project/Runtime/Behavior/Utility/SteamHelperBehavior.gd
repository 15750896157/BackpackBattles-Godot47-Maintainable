extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/SteamHelper.gd")

static func _ready(subject: Receiver) -> void:
	subject.process_mode = Node.PROCESS_MODE_ALWAYS
	subject.set_process(false)
	subject.IS_INIT = true
	subject.IS_OWNED = true
	subject.IS_ONLINE = true # Local service availability, not Internet connectivity.
	subject.APP_ID = Steam.getAppID()
	subject.STEAM_ID = Steam.getSteamID()
	subject.STEAM_NAME = Steam.getPersonaName()
	subject.GAME_LANG = Steam.getCurrentGameLanguage()
	subject.LOCALE = subject.langCodes.get(subject.GAME_LANG, "en")
	subject.STEAMDECK = false
	subject.getAllStats()
	subject.achievementTimer = Timer.new()
	subject.achievementTimer.one_shot = true
	subject.add_child(subject.achievementTimer)
	subject.achievementTimer.timeout.connect(subject.showNextAchievement)
	print("Local profile services ready: ", subject.STEAM_NAME)

static func updateRichPresence(subject: Receiver):
	if not subject.IS_INIT:
		return

	if Game.buildHistory.isOpen or Game.curMode == Game.Mode.History:
		subject.addRichPresence("steam_display", "#History")
	elif Game.state == Game.State.Title:
		subject.addRichPresence("steam_display", "#status_Menu")
	else:
		subject.addRichPresence("gamemode", Game.Mode.keys()[Game.curMode])
		subject.addRichPresence("class", Game.getClassOrSubclass())
		subject.addRichPresence("numwins", str(Game.getNumWins()))
		subject.addRichPresence("roundnum", str(Game.curRound))
		subject.addRichPresence("steam_display", "#status_Ingame")

static func unlockAchievement(subject: Receiver, aName: String, allowInCustom):
	if Game.ACHIEVEMENTS_ENABLED and subject.STATS_RECEIVED:
		if subject.canUnlock(allowInCustom):

			var curState = Steam.getAchievement(aName)
			if curState.ret and not curState.achieved:
				Steam.setAchievement(aName)
				Util.eprint("Achievement unlocked: ", aName)
				subject.storeStats()

				subject.achievementQueue.push_back(aName)
				if subject.achievementTimer.is_stopped():
					subject.showNextAchievement()

	if Game.EDITOR and subject.canUnlock(allowInCustom) and not aName in subject.unlockedThisSession:
		subject.unlockedThisSession[aName] = true
		Util.eprint("Would unlocked achievement ", aName)
