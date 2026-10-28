extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://CharacterClasses/CharacterClass.gd")

static func loadSounds(subject: Receiver, classIdentifier: String):
	var dir = LegacyDirectory.new()
	var directories = []
	var files = []
	var path = "res://Assets/Sound/" + classIdentifier
	if dir.open(path) == OK:
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		Util.addDirectoryContents(dir, files, directories)

		for fileName in files:

			if fileName.ends_with(".ogg.import"):
				fileName = fileName.trim_suffix(".import")
				if "StartRun" in fileName:
					subject.runStartSounds.push_back(load(fileName))
				elif "Buy" in fileName:
					subject.buySounds.push_back(load(fileName))
				elif "RoundStart" in fileName:
					subject.roundStartSounds.push_back(load(fileName))
				elif "WinRound" in fileName:
					subject.winRoundSounds.push_back(load(fileName))
				elif "LoseRound" in fileName:
					subject.loseRoundSounds.push_back(load(fileName))
				elif "Clicked" in fileName:
					subject.clickedSounds.push_back(load(fileName))

				elif "Attack" in fileName:
					subject.attackSounds.push_back(load(fileName))
				elif "BattleRage" in fileName:
					subject.battleRageSound = load(fileName)

static func loadFiles(subject: Receiver, classIdentifier: String):
	subject.loadSounds(classIdentifier)
	subject.sprite_path = subject.spriteFormat.format({"class": classIdentifier})
	subject.chibi_path = subject.chibiSpriteFormat.format({"class": classIdentifier})
	if Expedition.enabled:
		subject.sprite_path = "res://PvE/Art/Portrait.tscn"
		subject.chibi_path = subject.sprite_path
