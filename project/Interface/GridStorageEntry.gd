extends FocusGrabbingControl

var physicalItems: Array
var item = null
var defaultSize
var multiplicityLabel
var labelNode
var labelPos: Vector2
var pickingEnabled: bool
var panel

func preset():
	multiplicityLabel = $Node2D/Multiplicity
	defaultSize = size
	labelNode = $Node2D
	labelPos = labelNode.position
	panel = $Panel

func _ready():
	super._ready()
	Util.tryConnect(self, "gui_input", self, "_gui_input")

func setItems(itemList: Array, wasJustAdded: bool, itemMaxScale):
	return load("res://Runtime/Behavior/Interface/GridStorageEntryBehavior.gd").setItems(self, itemList, wasJustAdded, itemMaxScale)

func setNotEditable():
	panel.modulate = Color(0.5, 0.5, 0.5)
	item.modulate.a = 0.5
	pickingEnabled = false
	item.disableFocus()
	item.disableTooltip()

func setEditable():
	pickingEnabled = true

func onHover():
	super.onHover()
	item.hover()
	for physicalItem in physicalItems:
		physicalItem.previewFusions()

func onHoverEnd():
	super.onHoverEnd()
	item.hoverEnd()

func _gui_input(event):
	load("res://Runtime/Behavior/Interface/GridStorageEntryBehavior.gd")._gui_input(self, event)

func returnToObjectPool():
	if item != null:
		item.discard()
	item = null
	physicalItems.clear()
	ObjectPool.returnInstance(self)
