extends Control

const checkmark = preload("res://Interface/Checkmark.png")
const transparentCheckmark = preload("res://Interface/Checkmark_transparent.png")
const stylebox_player = preload("res://Interface/Lobbies/MemberStylebox_Player.tres")
const stylebox_opponent = preload("res://Interface/Lobbies/MemberStylebox_Opponent.tres")

var rankingLabel
var nameLabel
var winLabel
var triesLabel
var classIcon
var statusIcon
var hostIcon
var scoreLabel
var kickButton

var steamId: int
var memberData: LobbyMemberData
var isPlayer: bool
var isHost: bool

func init():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyScoreboardEntryBehavior.gd").init(self)

func setPlayerId(_steamId: int):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyScoreboardEntryBehavior.gd").setPlayerId(self, _steamId)

func updatePlayerData():
	classIcon.texture = Game.classIcons[memberData.characterClass]

func onFightFinished():
	winLabel.text = str(memberData.getCurrentWins())

func setStatus(_status):
	pass

func setRanking(rank):
	rankingLabel.text = str(rank)

func onCombatStart():
	statusIcon.texture = null

func onReady():
	statusIcon.texture = transparentCheckmark

func onRoundDataReceived(roundNum):
	if roundNum == Game.curRound:
		statusIcon.texture = checkmark

func onKickButtonPressed():
	RunDatabase.lobbies.kickMember(steamId)
