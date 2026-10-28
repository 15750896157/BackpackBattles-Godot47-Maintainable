extends Button
class_name ItemListButton

signal list_opened
signal list_closed
signal item_selected

@export var OPTION = ""
@export var translate = false
@export var openWithClick = false
@export var warpPointXFactor = 0.5 # (float, 0.0, 1.0, 0.1)

@onready var itemList = $ItemList
@onready var defaultIcon = icon

var hoverRect: Rect2
const TOPLEFT_MARGIN = Vector2(50, 50)
const BOTTOMRIGHT_MARGIN = Vector2(50, 80)

var rawItems = []
var focusLostFrame: int
var openFrame: int
var icons = {}
var hovered = false

func _ready() -> void :
	load("res://Runtime/Behavior/Interface/Options/ItemListButtonBehavior.gd")._ready(self)

func addItem(itemText, itemIcon = null):
	return load("res://Runtime/Behavior/Features/Interface/Options/ItemListButtonBehavior.gd").addItem(self, itemText, itemIcon)

func selectItemByIndex(index):
	itemList.select(index)
	updateText(index)

func updateLocale():
	return load("res://Runtime/Behavior/Interface/Options/ItemListButtonBehavior.gd").updateLocale(self)

func widen(toFitText, iconToFit = null):
	return load("res://Runtime/Behavior/Interface/Options/ItemListButtonBehavior.gd").widen(self, toFitText, iconToFit)

func updateText(index):
	return load("res://Runtime/Behavior/Interface/Options/ItemListButtonBehavior.gd").updateText(self, index)

func selectItem(itemText):
	var index = 0
	for i in rawItems.size():
		if rawItems[i] == itemText:
			index = i
			break
	selectItemByIndex(index)

func onHover():
	hovered = true
	if not Game.itemListOpened:
		Util.grabFocus(self)
		if not openWithClick:
			showItemList()

func onListClosed():
	if hovered:
		onHover()

func onClicked():
	if ( not Game.itemListOpened and
		openWithClick and
		Util.getFrameCounter_process() > focusLostFrame + 1):
		showItemList()

func showItemList():
	return load("res://Runtime/Behavior/Features/Interface/Options/ItemListButtonBehavior.gd").showItemList(self)

func calcHoverRect():
	return load("res://Runtime/Behavior/Features/Interface/Options/ItemListButtonBehavior.gd").calcHoverRect(self)

func onHoverEnd():
	Game.onHoverInteractableEnd(self)
	hovered = false

func clearList():
	itemList.clear()
	itemList.size.x = 0
	rawItems.clear()

func onFocusLost():

	if not hoverRect.has_point(get_global_mouse_position()):
		hideItemList()
		focusLostFrame = Util.getFrameCounter_process()

func onItemSelected(index: int):
	return load("res://Runtime/Behavior/Features/Interface/Options/ItemListButtonBehavior.gd").onItemSelected(self, index)

func hideItemList():
	if itemList.visible:
		itemList.hide()
		set_process(false)
		emit_signal("list_closed")
		Game.onItemListClosed()

func _process(_delta: float) -> void :
	load("res://Runtime/Behavior/Interface/Options/ItemListButtonBehavior.gd")._process(self, _delta)

func _exit_tree():
	hideItemList()

func onGetRects():
	return load("res://Runtime/Behavior/Features/Interface/Options/ItemListButtonBehavior.gd").onGetRects(self)

func onCursorWarp():
	return load("res://Runtime/Behavior/Interface/Options/ItemListButtonBehavior.gd").onCursorWarp(self)

