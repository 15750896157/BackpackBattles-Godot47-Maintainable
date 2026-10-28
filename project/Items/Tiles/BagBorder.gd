extends Sprite2D

@onready var bag = get_parent().get_parent()

func _ready() -> void :
	load("res://Runtime/Behavior/Features/Items/Tiles/BagBorderBehavior.gd")._ready(self)

func onItemPickedUp():
	return load("res://Runtime/Behavior/Features/Items/Tiles/BagBorderBehavior.gd").onItemPickedUp(self)

func onItemDropped(_item, dropResult):
	if dropResult != Item.DropResult.Hotswap or not bag.showBagBorderForItem(Game.draggedItem):
		set_process(false)
		hide()

func _process(delta):
	return load("res://Runtime/Behavior/Features/Items/Tiles/BagBorderBehavior.gd")._process(self, delta)

