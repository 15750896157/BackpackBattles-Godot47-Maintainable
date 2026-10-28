extends Node2D

@onready var leagueSprite = $League
@onready var rankLabel = $Rank
@onready var rankLight = $RankLight
@onready var star = $Star

func setItem(item: Item):
	return load("res://Runtime/Callbacks/Interface/ItemLibrary/CallbacksI.gd").ForItemRecordIcons.setItem(self, item)

