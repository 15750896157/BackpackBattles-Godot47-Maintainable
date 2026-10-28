extends Node2D

@onready var icon = $ClassIcon
@onready var rankLabel = $Ranking
@onready var emblem = $LeagueEmblem

func setLeague(classI: int, leagueExact: float):
	return load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForSeasonClassRank.setLeague(self, classI, leagueExact)

