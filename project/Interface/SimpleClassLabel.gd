extends Label

func _ready() -> void :
	Game.connect("character_changed", Callable(self, "updateLocale"))
	Util.localizeFonts(self)
	add_to_group("Localized")
	updateLocale()
	if Expedition.enabled:
		call_deferred("_refresh_pve")

func updateLocale():
	text = Game.getClassName()
	set("theme_override_colors/font_color", Game.getNativeClassColor())

func _refresh_pve():
	while not Expedition.initialized:
		await get_tree().process_frame
	updateLocale()
