extends Node2D

const openHeight = 110.0
const hiddenHeight = 50.0
const windParticles = preload("res://Interface/WindParticles.tscn")
const windSound = preload("res://Assets/Sound/Swoosh1.wav")

@onready var panel = $Panel
@onready var toolbarButton = $ToolbarButton
@onready var closedY = position.y
@onready var xPos = position.x

var particleReadyTime = 0.0
var isOpen = false
var tween: Tween
var nodesToHide: Array

@onready var buttons = [
	$UndoButton, $RedoButton, $PushToStorageButton,
	$ToolbarButton, $GridStorageButton,
	$EditModeButtons/Default, $EditModeButtons/BagLayer, $EditModeButtons/ItemLayer]
@onready var tutorialAni = $AnimationPlayer

func _ready():
	return load("res://Runtime/Behavior/Interface/ShopToolbarBehavior.gd")._ready(self)

func onShopToTitle():
	tween = Util.refreshTween(tween)
	tween.tween_property(self, "position:y", closedY + hiddenHeight, 0.1)

func onShopToCombat():
	show()
	set_process(true)

func onCombatEntered():
	hide()
	set_process(false)

func onTitleToShop():
	unhide()

func unhide():
	return load("res://Runtime/Behavior/Features/Interface/ShopToolbarBehavior.gd").unhide(self)

func onCombatToShop():
	return load("res://Runtime/Behavior/Features/Interface/ShopToolbarBehavior.gd").onCombatToShop(self)

func _process(delta):
	position.x = Game.shopSceneNode.position.x + xPos

func onToolbarButtonPressed():
	if isOpen:
		close()
	else:
		open()

func isInteractable() -> bool:
	return ( not InputBlocker.isActive() and
			Game.draggedItem == null and
			Game.isShopActive())

func open():
	return load("res://Runtime/Behavior/Interface/ShopToolbarBehavior.gd").open(self)

func close():
	return load("res://Runtime/Behavior/Features/Interface/ShopToolbarBehavior.gd").close(self)

func closeFinished():
	for node in nodesToHide:
		node.hide()

func onUndoPressed():
	if not isInteractable(): return

	Game.undoStack.undo()

func onRedoPressed():
	if not isInteractable(): return

	Game.undoStack.redo()

func onPushToStoragePressed():
	return load("res://Runtime/Behavior/Features/Interface/ShopToolbarBehavior.gd").onPushToStoragePressed(self)

func _unhandled_input(event):
	if not isInteractable(): return
	if Util.isActionPressed_event(event, "push_all_to_storage"):
		onPushToStoragePressed()

func checkUndoRedo():
	$UndoButton.disabled = not Game.undoStack.canUndo()
	$RedoButton.disabled = not Game.undoStack.canRedo()

func onMenuOpened():

	for button in buttons:
		button.onHoverEnd()

	hide()
	show()

func onGridStoragePressed(toggleState):
	if toggleState:
		Game.gridStorage.open()
	else:
		Game.gridStorage.close()

func onGridStorageToggled():
	$GridStorageButton.set_pressed(Game.gridStorage.visible)

func onCursorWarp():
	return load("res://Runtime/Behavior/Features/Interface/ShopToolbarBehavior.gd").onCursorWarp(self)

