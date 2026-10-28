extends FocusGrabbingButton

const anvil_hovered = preload("res://Interface/AnvilButton_hovered.png")
const anvil = preload("res://Interface/AnvilButton.png")

func _ready():
	super._ready()
	if not Game.recipeBook:
		Game.recipeBook = preload("res://Runtime/Loading/LazyPanel.gd").new()
		Game.recipeBook.kind = "crafting"
		add_child(Game.recipeBook)
	Game.connect("warp_cursor_shop", Callable(self, "onCursorWarp"))

func onHover():
	super.onHover()
	self.icon = anvil_hovered

func onHoverEnd():
	super.onHoverEnd()
	self.icon = anvil

func onPressed():
	if not Game.draggedItem and not InputBlocker.isActive():
		Expedition.show_crafting()
		onHoverEnd()
	return

func onCursorWarp():
	if is_visible_in_tree():
		Game.addPointOfInterest(global_position + pivot_offset)
