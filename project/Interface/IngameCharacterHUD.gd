extends Node2D

@onready var unrankedLabel = $Unranked
@onready var rankingLabel = $Ranking
@onready var emblem = $LeagueEmblem
@onready var surviveLabel = $Survive
@onready var survivalSkull = $SurvivalSkull
@onready var lobbyNode = $Lobby
@onready var lobbyRoundsLabel = $Lobby/LobbyRounds
@onready var roundNode = $Round
@onready var winsNode = $Wins
@onready var triesNode = $Tries
@onready var customRulesIcon = $CustomRulesIcon

func _ready() -> void :
	Game.connect("switch_to_shop", Callable(self, "updateLabels"))
	add_to_group("Localized")
	if Expedition.enabled:
		unrankedLabel.translationKey = ""
		call_deferred("updateLabels")

func updateLabels():
	return load("res://Runtime/Callbacks/Interface/CallbacksI.gd").ForIngameCharacterHUD.updateLabels(self)

func updateLocale():
	updateLabels()
	return
