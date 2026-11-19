extends Node

const MAX_SKINS = 16

var skins = []

func getNumSkinsForClass(classI, style) -> int:
	return getSkinsForClass(classI, style).size()

func getSkinsForClass(classI, style) -> Array:
	return skins[classI][style]

func getSkinFromId(classI, style, id):
	return Util.nDimArrayGet(skins, [classI, style, id],
		skins[classI][style][0])

func getRandomSkinFor(classI, style, slot):
	return load("res://Code/Runtime/Behavior/Utility/SkinBookBehavior.gd").getRandomSkinFor(self, classI, style, slot)

const scenePathFormat = "res://Art/CharacterClasses/{class}/Skins/{style}/{skin}/{skin}.tscn"
const iconPathFormat = "res://Art/CharacterClasses/{class}/Skins/{style}/{skin}/{skin}.png"
const hoveredIconPathFormat = "res://Art/CharacterClasses/{class}/Skins/{style}/{skin}/{skin}_hovered.png"

func _ready():
	return load("res://Code/Runtime/Behavior/Utility/SkinBookBehavior.gd")._ready(self)

class OrderSorter:
	static func sort(skin1: CharacterSkin, skin2: CharacterSkin):
		return skin1.order < skin2.order
