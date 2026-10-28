extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Options/ItemListButton.gd")

static func _ready(subject: Receiver) -> void :

	subject.itemList.set("theme_override_fonts/font", subject.get("theme_override_fonts/font"))
	subject.itemList.hide()
	subject.set_process(false)
	subject.connect("mouse_entered", Callable(subject, "onHover"))
	subject.connect("mouse_exited", Callable(subject, "onHoverEnd"))
	subject.connect("button_down", Callable(subject, "onClicked"))
	subject.itemList.connect("focus_exited", Callable(subject, "onFocusLost"))
	Util.localizeFonts(subject)

	subject.itemList.set_fixed_icon_size(Vector2(30, 30))

	Game.connect("item_list_closed", Callable(subject, "onListClosed"))
	Game.connectToGetRectsSignals(subject, "onGetRects")
	Game.connectToWarpCursorSignals(subject, "onCursorWarp")

static func updateLocale(subject: Receiver):
	if subject.itemList:
		if subject.translate:
			subject.itemList.size.x = 0
			for i in subject.rawItems.size():
				var newText = Util.tra(subject.rawItems[i])
				subject.itemList.set_item_text(i, newText)
				subject.widen(newText, subject.icons[i])

		var selected = subject.itemList.get_selected_items()
		if not selected.is_empty():
			subject.updateText(selected[0])

static func widen(subject: Receiver, toFitText, iconToFit):
	var iconSize = 0
	if iconToFit != null:
		iconSize = 30
	var font = subject.itemList.get_theme_font("font")
	var font_size = font.size if font is LegacyFont else subject.itemList.get_theme_font_size("font_size")
	subject.itemList.size.x = max(subject.itemList.size.x,
		font.get_string_size(toFitText, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16 + iconSize)

static func updateText(subject: Receiver, index):
	subject.text = ""
	if subject.OPTION != "":
		subject.text = Util.tr(subject.OPTION) + ": "

	subject.text += subject.itemList.get_item_text(index)
	var _icon = subject.itemList.get_item_icon(index)
	if _icon != null:
		subject.icon = _icon
		subject.expand_icon = true

	else:
		subject.icon = subject.defaultIcon
		subject.expand_icon = false

static func _process(subject: Receiver, _delta: float) -> void :
	if not subject.hoverRect.has_point(subject.get_global_mouse_position()):
		subject.hideItemList()

	if Util.getFrameCounter_process() > subject.openFrame + 1:
		for i in subject.itemList.get_item_count():
			subject.itemList.set_item_custom_bg_color(i, Color.TRANSPARENT)
			subject.itemList.set_item_custom_fg_color(i, Game.SOFTWHITE)

		var localPos = subject.get_global_mouse_position() - subject.itemList.global_position
		var hoveredItem = subject.itemList.get_item_at_position(localPos)
		if hoveredItem >= 0:
			subject.itemList.set_item_custom_bg_color(hoveredItem, Game.SOFTWHITE)
			subject.itemList.set_item_custom_fg_color(hoveredItem, Util.paramColor)

			if Util.isActionJustPressed("ui_select", false):
				subject.selectItemByIndex(hoveredItem)
				subject.onItemSelected(hoveredItem)

static func onCursorWarp(subject: Receiver):
	if subject.itemList.visible:
		var size = Vector2(max(subject.itemList.size.x, subject.size.x), subject.itemList.size.y)
		var step = size.y / subject.rawItems.size()
		for i in subject.rawItems.size():
			var pos = subject.global_position
			pos.x += size.x * subject.warpPointXFactor
			pos.y += size.y + step * (i + 0.5)
			Game.addPointOfInterest(pos, null, null, 2)
