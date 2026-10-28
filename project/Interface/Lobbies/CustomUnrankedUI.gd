extends Node2D

signal close_requested(cancelled: bool)

const buttonGroup = preload("res://Interface/Lobbies/MatchAgainstButtonGroup.tres")

var leagueButtons = []

@onready var customRulesInput = $Rules

func _ready():
	load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksC.gd").ForCustomUnrankedUI._ready(self)

func open():
	return load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksC.gd").ForCustomUnrankedUI.open(self)

func close():
	pass

func onCancelPressed():
	close()
	emit_signal("close_requested", true)

func onLeagueSelected(league):
	CustomRules.setLeagueToMatch(league)

func startGame():
	Game.startFreshRun(Game.Mode.Unranked)
	Game.titleScreen.clearItems()

	close()
	emit_signal("close_requested", false)
