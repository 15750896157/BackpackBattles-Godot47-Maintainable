extends FocusGrabbingButton

const itemLibraryScene = preload("res://Runtime/Loading/LazyCatalog.gd")
const normalTex = preload("res://Interface/ItemLibrary/ItemLibraryButton.png")
const hoveredTex = preload("res://Interface/ItemLibrary/ItemLibraryButton_hovered.png")

func _ready():
	super._ready()
	if not Game.itemLibrary:
		Game.itemLibrary = itemLibraryScene.new()
		add_child(Game.itemLibrary)
		Util.callNextFrame(Game.itemLibrary, "init")
	Game.connect("warp_cursor_shop", Callable(self, "onCursorWarp"))

func onHover():
	super.onHover()
	self.icon = hoveredTex

func onHoverEnd():
	super.onHoverEnd()
	self.icon = normalTex

func onPressed():
	if not Game.draggedItem and not InputBlocker.isActive():
		Expedition.show_codex()
		onHoverEnd()
	return

func onCursorWarp():
	if is_visible_in_tree():
		Game.addPointOfInterest(global_position + pivot_offset)
