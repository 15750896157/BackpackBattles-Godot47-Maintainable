extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/ShopToolbar.gd")

static func _ready(subject: Receiver):
	subject.set_process(false)
	subject.position.y = subject.closedY + subject.hiddenHeight

	subject.toolbarButton.connect("pressed", Callable(subject, "onToolbarButtonPressed"))
	subject.get_node("UndoButton").connect("pressed", Callable(subject, "onUndoPressed"))
	subject.get_node("RedoButton").connect("pressed", Callable(subject, "onRedoPressed"))
	subject.get_node("PushToStorageButton").connect("pressed", Callable(subject, "onPushToStoragePressed"))
	subject.get_node("GridStorageButton").connect("toggled", Callable(subject, "onGridStoragePressed"))
	Game.gridStorage.connect("toggled", Callable(subject, "onGridStorageToggled"))
	Game.undoStack.connect("state_added", Callable(subject, "checkUndoRedo"))
	Game.undoStack.connect("state_changed", Callable(subject, "checkUndoRedo"))

	Game.connect("return_to_title", Callable(subject, "onShopToTitle"))
	Game.connect("switching_to_combat", Callable(subject, "onShopToCombat"))
	Game.connect("combat_scene_entered", Callable(subject, "onCombatEntered"))
	Game.connect("title_to_shop", Callable(subject, "onTitleToShop"))
	Game.connect("switch_to_shop", Callable(subject, "onCombatToShop"))
	Game.connect("menu_open", Callable(subject, "onMenuOpened"))
	Game.connect("warp_cursor_shop", Callable(subject, "onCursorWarp"))

	for child in subject.get_children():
		if (child is CanvasItem and
			child != subject.panel and
			child != subject.toolbarButton):
			subject.nodesToHide.push_back(child)
			child.hide()

static func open(subject: Receiver):
	if not subject.isInteractable(): return

	subject.isOpen = true
	subject.toolbarButton.flip_v = true

	for node in subject.nodesToHide:
		node.show()

	subject.tween = Util.refreshTween(subject.tween)
	subject.tween.tween_property(subject, "position:y", subject.closedY - subject.openHeight, 0.1)

	Game.setTutorialDone(Game.TutorialSteps.Toolbar)
	subject.tutorialAni.play("RESET")
