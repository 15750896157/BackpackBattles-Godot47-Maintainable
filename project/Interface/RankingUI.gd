extends Node2D

@onready var leagueProgressUI = $LeagueProgress
@onready var switchModeIcon = $SwitchMode

func _ready() -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksR.gd").ForRankingUI._ready(self)

func updateLocale():
	return load("res://Runtime/Callbacks/Interface/CallbacksR.gd").ForRankingUI.updateLocale(self)

