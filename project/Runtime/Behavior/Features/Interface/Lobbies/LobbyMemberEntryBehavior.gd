extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/LobbyMemberEntry.gd")

static func init(subject: Receiver):
	subject.classIcon = subject.get_node("HboxContainer/ClassIcon")
	subject.nameLabel = subject.get_node("HboxContainer/Name")
	subject.kickButton = subject.get_node("HboxContainer/KickButton")
	Util.addFallbackFonts(subject.nameLabel.get("theme_override_fonts/font"))

static func setSteamId(subject: Receiver, _steamId: int):
	subject.init()
	subject.steamId = _steamId
	subject.memberData = RunDatabase.lobbies.getMemberData(subject.steamId)
	subject.isPlayer = subject.memberData.isSelf()
	subject.isHost = RunDatabase.lobbies.isMemberHost(subject.steamId)
	subject.kickButton.visible = RunDatabase.lobbies.isHost() and not subject.isHost
	subject.updatePlayer()
	subject.memberData.connect("data_changed", Callable(subject, "updatePlayer"))

static func updatePlayer(subject: Receiver):
	subject.nameLabel.text = subject.memberData.playerName
	if subject.memberData.loadout == Game.Loadout.RandomCharacter:
		subject.classIcon.texture = Game.randomClassIcon
	else:
		subject.classIcon.texture = Game.classIcons[subject.memberData.characterClass]
