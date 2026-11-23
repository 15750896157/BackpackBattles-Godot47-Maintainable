extends Node2D

@export var showEmptyStar = false

var lightColors = {
	Game.ItemRecordStar.Bronze: Color(1, 0.842957, 0.675781),
	Game.ItemRecordStar.Silver: Color(0.84235, 0.846648, 0.857422),
	Game.ItemRecordStar.Gold: Color(0.96875, 0.893547, 0.618713),
	Game.ItemRecordStar.Diamond: Color(0.992188, 0.773209, 0.91948)
}

var stars = {
	Game.ItemRecordStar.Bronze: preload("res://PvE/UI/ItemLibrary/BronzeStar.png"),
	Game.ItemRecordStar.Silver: preload("res://PvE/UI/ItemLibrary/SilverStar.png"),
	Game.ItemRecordStar.Gold: preload("res://PvE/UI/ItemLibrary/GoldStar.png"),
	Game.ItemRecordStar.Diamond: preload("res://PvE/UI/Common/Diamond.png")
}

const noStarModulate = Color(0.054902, 0.039216, 0.031373, 0.333333)

@onready var starSprite = $Sprite2D
@onready var starLight = $Light3D

func setStarType(starType: int):
	return load("res://Code/Runtime/Callbacks/Interface/ItemLibrary/CallbacksI.gd").ForItemRecordStar.setStarType(self, starType)

func setItem(item: Item):
	return load("res://Code/Runtime/Callbacks/Interface/ItemLibrary/CallbacksI.gd").ForItemRecordStar.setItem(self, item)

