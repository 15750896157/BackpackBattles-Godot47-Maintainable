extends FocusGrabbingTextureButton

func _ready():
	super._ready()
	Game.options = preload("res://Runtime/Loading/LazyPanel.gd").new()
	Game.options.kind = "settings"
	add_child(Game.options)
	Game.connect("warp_cursor_shop", Callable(self, "onCursorWarp"))
	Game.connect("warp_cursor_title", Callable(self, "onCursorWarp"))
	Game.connect("warp_cursor_combat", Callable(self, "onCursorWarp"))

func onPressed():
	if Expedition.initialized:
		Expedition.show_settings()
		return
	super.onPressed()
	if Game.options.canOpen():
		Game.options.open()
		hideHoverNodeAndTooltip()

func _unhandled_input(event: InputEvent) -> void :
	if InputBlocker.isActive(): return

	if Util.isActionPressed_event(event, "options"):
		if Expedition.initialized:
			Expedition.show_settings()
			get_viewport().set_input_as_handled()
			return
		if Game.options.canOpen():
			Game.options.open()

func onCursorWarp():
	Game.addPointOfInterest(global_position + size * 0.5)
