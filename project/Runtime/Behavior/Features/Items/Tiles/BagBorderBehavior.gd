extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Tiles/BagBorder.gd")

static func _ready(subject: Receiver) -> void :
	if (subject.bag.ownerType == Item.Owner.Shop or
		subject.bag.ownerType == Item.Owner.PlayerInventory or
		subject.bag.ownerType == Item.Owner.PlayerStorageBox):
		subject.hide()
		subject.set_process(false)
		Game.connect("item_picked_up", Callable(subject, "onItemPickedUp"))
		Game.connect("item_dropped", Callable(subject, "onItemDropped"))
	else:
		subject.queue_free()

static func onItemPickedUp(subject: Receiver):
	if subject.bag.placed:
		subject.show()
		if subject.bag.showBagBorderForItem(Game.draggedItem):
			subject.set_process(true)
		else:

			subject.self_modulate = Color(1.6, 1.6, 1.6, 0.0)

static func _process(subject: Receiver, delta):

	subject.self_modulate = Color(1.3, 1.3, 1.3, 1)

	for cell in subject.bag.occupiedCells:
		if subject.bag.inventory.isHovered(cell):
			subject.self_modulate = Color(2.5, 2.5, 2.5, 1)
			break
