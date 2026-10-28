extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/LobbyScoreboardEntry.gd")

static func init(subject: Receiver):
	subject.rankingLabel = subject.get_node("HboxContainer/Ranking")
	subject.nameLabel = subject.get_node("HboxContainer/Name")
	subject.winLabel = subject.get_node("HboxContainer/Wins")
	subject.triesLabel = subject.get_node("HboxContainer/Tries")
	subject.statusIcon = subject.get_node("HboxContainer/StatusIcon")
	subject.classIcon = subject.get_node("HboxContainer/ClassIcon")
	subject.hostIcon = subject.get_node("HostIcon")
	subject.scoreLabel = subject.get_node("HboxContainer/Score")
	subject.kickButton = subject.get_node("HboxContainer/KickButton")

	Game.connect("combat_scene_entered", Callable(subject, "onCombatStart"))
	Util.addFallbackFonts(subject.nameLabel.get("theme_override_fonts/font"))

static func setPlayerId(subject: Receiver, _steamId: int):
	subject.init()
	subject.steamId = _steamId
	subject.memberData = RunDatabase.lobbies.getMemberData(subject.steamId)
	subject.isPlayer = subject.memberData.isSelf()
	subject.isHost = RunDatabase.lobbies.isMemberHost(subject.steamId)
	subject.kickButton.visible = RunDatabase.lobbies.isHost() and not subject.isHost
	subject.nameLabel.text = subject.memberData.playerName
	subject.winLabel.text = str(subject.memberData.getCurrentWins())

	if subject.isPlayer:
		subject.set("theme_override_styles/panel", subject.stylebox_player)
	else:
		subject.set("theme_override_styles/panel", subject.stylebox_opponent)

	subject.hostIcon.visible = subject.isHost
	subject.statusIcon.texture = null
	subject.memberData.connect("ready", Callable(subject, "onReady"))
	subject.memberData.connect("round_received", Callable(subject, "onRoundDataReceived"))

	if RunDatabase.lobbies.isHost():
		subject.custom_minimum_size.x = 450
	else:
		subject.custom_minimum_size.x = 409

	subject.updatePlayerData()

	Util.callDelayed(subject, "updatePlayerData", 1.0)
