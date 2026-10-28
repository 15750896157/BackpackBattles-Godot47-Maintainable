extends FocusGrabbingButton

@onready var icon_normal = icon
const icon_hovered = preload("res://Interface/HistoryButton_hovered.png")

func _ready():
	super._ready()
	if Game.buildHistoryDB != null:
		Game.buildHistory = preload("res://Runtime/Loading/LazyPanel.gd").new()
		Game.buildHistory.kind = "history"
		add_child(Game.buildHistory)
	else:
		queue_free()

func onHover():
	super.onHover()
	self.icon = icon_hovered

func onHoverEnd():
	super.onHoverEnd()
	self.icon = icon_normal

func onPressed():
	super.onPressed()
	if not Game.draggedItem:
		Expedition.show_combat_log()
		onHoverEnd()
	return
