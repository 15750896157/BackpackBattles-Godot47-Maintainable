extends Node2D

@onready var rankingLabel = $Ranking
@onready var leagueLabel = $League
@onready var leagueProgressBar = $LeagueProgressBar
@onready var emblem = $LeagueEmblem

func _ready():
	leagueProgressBar.material = leagueProgressBar.material.duplicate()
	Util.localizeFonts(leagueLabel)

func updateUI(charClass):
	return load("res://Runtime/Callbacks/Interface/CallbacksL.gd").ForLeagueProgressUI.updateUI(self, charClass)

