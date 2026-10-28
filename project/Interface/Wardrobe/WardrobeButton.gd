extends FocusGrabbingTextureButton

@onready var buttonLabel = get_parent().get_node("%WardrobeLabel")

var loading: bool = false

func _ready():
	super._ready()

func onPressed():
	super.onPressed()
	if not Expedition.initialized or Game.draggedItem or loading: return
	if is_instance_valid(Game.wardrobe):
		Game.wardrobe.close()
		return
	loading = true
	var epoch = Expedition.popup_epoch
	var path = "res://Interface/Wardrobe/Wardrobe.tscn"
	if not await AssetStream.prepare([path], "wardrobe"):
		loading = false
		return
	var menu = await AssetStream.instantiate_path(path, "wardrobe")
	loading = false
	if menu == null: return
	if Expedition.popup_epoch != epoch or Expedition.panel.visible or Game.state != Game.State.Title:
		menu.free()
		AssetStream.release("wardrobe")
		return
	Game.wardrobe = menu
	menu.closed.connect(onWardrobeClosed)
	menu.open()
	buttonLabel.translationKey = "BUTTON_CloseWardrobe"
	buttonLabel.updateText()

func onWardrobeClosed():
	buttonLabel.translationKey = "BUTTON_OpenWardrobe"
	buttonLabel.updateText()
