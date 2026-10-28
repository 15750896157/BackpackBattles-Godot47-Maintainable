extends Node2D
class_name Socket

@onready var sprite = $Sprite2D

var item = null
var gem = null

func _ready() -> void :
	hideSocket()
	Util.eassert(visible)

func isEmpty() -> bool:
	return gem == null

func getGem():
	return gem

func getItem():
	return item

func hideSocket():
	if isEmpty():
		sprite.hide()

func showSocket():

	sprite.show()

func isAvailable() -> bool:
	return ((item.ownerType == Item.Owner.PlayerInventory or
			item.ownerType == Item.Owner.PlayerStorageBox) and
			not item.sold)

func onHoverWithGem():
	sprite.self_modulate = Color(1.73, 1.54, 0.37)
	sprite.scale = Vector2(0.43, 0.43)

	if gem != null:
		gem.onHotSwapHoverWithGem()

func onHoverEndWithGem():
	sprite.self_modulate = Color.WHITE
	sprite.scale = Vector2(0.372, 0.372)

	if gem != null:
		gem.onHotSwapHoverWithGemEnd()

func onDropGem(droppedGem):
	return load("res://Runtime/Callbacks/Items/CallbacksG.gd").ForGemSocket.onDropGem(self, droppedGem)

func onPickupGem():
	var pickedUpGem = gem
	gem = null

	pickedUpGem.removeFromSocket()
