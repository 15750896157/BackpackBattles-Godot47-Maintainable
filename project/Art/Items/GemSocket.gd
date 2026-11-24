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
	# 已换新美术的物品：老圆环是按旧图标的位置摆的，套在新图标上会错位，所以不再显示。
	if item != null and item.has_meta("supplied_art_path"):
		return
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
	return load("res://Code/Runtime/Callbacks/Items/CallbacksG.gd").ForGemSocket.onDropGem(self, droppedGem)

func onPickupGem():
	var pickedUpGem = gem
	gem = null

	pickedUpGem.removeFromSocket()
