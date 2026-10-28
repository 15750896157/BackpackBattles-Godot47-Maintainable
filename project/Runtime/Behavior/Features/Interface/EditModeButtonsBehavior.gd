extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/EditModeButtons.gd")

static func _ready(subject: Receiver):
	Game.connect("edit_mode_changed", Callable(subject, "onEditModeChanged"))
	subject.defaultButton.connect("pressed", Callable(subject, "onDefaultPressed"))
	subject.bagLayerButton.connect("pressed", Callable(subject, "onBagLayerPressed"))
	subject.itemLayerButton.connect("pressed", Callable(subject, "onItemLayerPressed"))

static func _unhandled_input(subject: Receiver, event):
	if Util.isActionPressed_event(event, "edit_all"):
		subject.onDefaultPressed()
	elif Util.isActionPressed_event(event, "edit_bags"):
		subject.onBagLayerPressed()
	elif Util.isActionPressed_event(event, "edit_items"):
		subject.onItemLayerPressed()

static func onDefaultPressed(subject: Receiver):
	if not subject.isInteractable(): return
	if Game.inventoryEditMode != Game.InventoryEditMode.Default:
		Game.setInventoryEditMode(Game.InventoryEditMode.Default)
		Game.cancelSwitch()

static func onBagLayerPressed(subject: Receiver):
	if not subject.isInteractable(): return
	if Game.inventoryEditMode != Game.InventoryEditMode.BagLayer:
		Game.setInventoryEditMode(Game.InventoryEditMode.BagLayer)
	else:
		Game.setInventoryEditMode(Game.InventoryEditMode.Default)
	Game.cancelSwitch()

static func onItemLayerPressed(subject: Receiver):
	if not subject.isInteractable(): return
	if Game.inventoryEditMode != Game.InventoryEditMode.ItemLayer:
		Game.setInventoryEditMode(Game.InventoryEditMode.ItemLayer)
	else:
		Game.setInventoryEditMode(Game.InventoryEditMode.Default)
	Game.cancelSwitch()

static func onEditModeChanged(subject: Receiver):
	match Game.inventoryEditMode:
		Game.InventoryEditMode.Default:
			subject.defaultButton.set_pressed(true)
		Game.InventoryEditMode.BagLayer:
			subject.bagLayerButton.set_pressed(true)
		Game.InventoryEditMode.ItemLayer:
			subject.itemLayerButton.set_pressed(true)
