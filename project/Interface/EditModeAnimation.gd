extends "res://Utility/PooledScene.gd"

var icons = {
	Game.InventoryEditMode.Default: preload("res://Interface/EditModeDefault.png"),
	Game.InventoryEditMode.BagLayer: preload("res://Interface/EditModeBags.png"),
	Game.InventoryEditMode.ItemLayer: preload("res://Interface/EditModeItems.png")
}

var gridStorageIcon = preload("res://Interface/GridStorage.png")

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
