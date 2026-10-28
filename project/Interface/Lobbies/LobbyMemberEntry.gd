extends Control

var nameLabel
var classIcon
var kickButton

var steamId: int
var memberData: LobbyMemberData
var isPlayer: bool
var isHost: bool

func init():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyMemberEntryBehavior.gd").init(self)

func setSteamId(_steamId: int):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyMemberEntryBehavior.gd").setSteamId(self, _steamId)

func updatePlayer():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyMemberEntryBehavior.gd").updatePlayer(self)

func onKickButtonPressed():
	RunDatabase.lobbies.kickMember(steamId)
