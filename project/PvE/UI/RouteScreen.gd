extends Control
## Editable route layout. It renders a prepared snapshot and only emits intentions.

signal choice_requested(index: int)
signal intel_requested(index: int)
signal back_requested
signal settings_requested
signal codex_requested

const CARD = preload("res://PvE/UI/RouteCard.tscn")
const REF = preload("res://PvE/UI/ReferenceCanvas.gd")

func configure(state: Dictionary, descriptions: Array[Dictionary], art: Dictionary, font: Font) -> bool:
	var pending: bool = state.route_pending
	var count := descriptions.size()
	if count < 1 or count > 3 or font == null or get_node("Cards").get_child_count() != 0:
		return false
	get_node("Background").visible = not pending
	get_node("Shade").visible = pending
	get_node("PendingHint").visible = pending
	_bind(get_node("."), state, art, font)
	var back: TextureButton = get_node("Back")
	back.name = "RouteCancel" if pending else "JourneyReturn"
	back.pressed.connect(back_requested.emit)
	get_node("JourneySettings").pressed.connect(settings_requested.emit)
	get_node("JourneyCodex").pressed.connect(codex_requested.emit)
	for index in count:
		var card: Control = CARD.instantiate()
		card.position.x = 104.0 + index * 606.0 if count == 3 else 310.0 + index * 780.0
		var row := descriptions[index]
		var choice: Button = card.get_node("Choice")
		var go: TextureButton = card.get_node("Go")
		var intel: TextureButton = card.get_node("Intel")
		choice.name = "RouteChoice_%d" % index
		choice.set_meta("route_index", index)
		go.name = "RouteGo_%d" % index
		go.set_meta("action_caption", row.prepare)
		intel.tooltip_text = row.intel
		choice.pressed.connect(choice_requested.emit.bind(index))
		go.pressed.connect(choice_requested.emit.bind(index))
		intel.pressed.connect(intel_requested.emit.bind(index))
		card.get_node("Tab").texture = art[row.tab]
		card.get_node("Portrait").texture = row.portrait
		card.get_node("Portrait").modulate = row.tint
		card.get_node("Portrait").name = "RoutePortrait_%d" % index
		_bind(card, row, art, font)
		if TranslationServer.get_locale().begins_with("zh"):
			card.get_node("PossibleRewards").hide()
			card.get_node("PossibleRewardsArt").show()
		if row.elite:
			var frame: TextureRect = card.get_node("Frame")
			frame.texture = art.route_card_elite
			frame.position -= Vector2(38,39)
			frame.size = Vector2(598,736)
			card.get_node("Motif").hide()
		if row.tab != "route_tab":
			for heading in [card.get_node("Name"), card.get_node("Subtitle")]:
				heading.add_theme_color_override("font_color", Color("fff0bb"))
		get_node("Cards").add_child(card)
	return true

func _bind(root: Control, data: Dictionary, art: Dictionary, font: Font) -> void:
	for node in root.find_children("*", "Control", true, false):
		if node.has_meta("route_texture"):
			var texture: Texture2D = art[node.get_meta("route_texture")]
			if node is TextureButton:
				node.texture_normal = texture
				node.mouse_entered.connect(REF.feedback.bind(node, Color(1.08, 1.06, 1.0)))
				node.mouse_exited.connect(REF.feedback.bind(node, Color.WHITE))
				node.button_down.connect(node.set_self_modulate.bind(Color(0.82, 0.82, 0.82)))
				node.button_up.connect(node.set_self_modulate.bind(Color.WHITE))
			else:
				node.texture = texture
			node.set_meta("reference_rect", Rect2(root.position + node.position, node.size))
		elif node is Label and node.has_meta("route_text"):
			_set_label(node, str(data.get(node.get_meta("route_text"), "")), font)

func _set_label(label: Label, value: String, font: Font) -> void:
	var extent := label.size
	var fitted := int(label.get_meta("route_font_size"))
	var lines := value.split("\n")
	while fitted > 16:
		var width := 0.0
		for line in lines:
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x)
		if width <= extent.x - 8 and font.get_height(fitted) * lines.size() <= extent.y:
			break
		fitted -= 1
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", fitted)
	label.text = value
