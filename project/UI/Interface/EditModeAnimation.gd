extends "res://Code/Utility/PooledScene.gd"

var icons = {
	Game.InventoryEditMode.Default: preload("res://UI/Interface/EditModeDefault.png"),
	Game.InventoryEditMode.BagLayer: preload("res://UI/Interface/EditModeBags.png"),
	Game.InventoryEditMode.ItemLayer: preload("res://UI/Interface/EditModeItems.png")
}

var gridStorageIcon = preload("res://PvE/UI/Inventory/GridStorage.png")

var sprite
var animation

func preset():
	sprite = $Sprite2D
	animation = $AnimationPlayer

func onEditModeChanged(editMode):
	sprite.texture = icons[editMode]
	animation.play("Appear")

func onGridStorageToggled():
	sprite.texture = gridStorageIcon
	animation.play("Appear")

func returnToObjectPool():
	Game.onEditModeAniFinished(self)
	super.returnToObjectPool()

func disappear():
	animation.stop()
	returnToObjectPool()
