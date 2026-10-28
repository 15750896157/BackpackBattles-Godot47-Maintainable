extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/LocalizedControl.gd")

static func _ready(subject: Receiver) -> void :
	Util.localizeFonts(subject)

	if (subject.autoMaxSize or
		("autowrap_mode" in subject and subject.get("autowrap_mode") == TextServer.AUTOWRAP_OFF)
		or subject.maxSize != 0):
		subject.shrink = true
		if subject.maxSize == 0:
			subject.maxSize = subject.size.x
		if subject.maxSizeY == 0:
			subject.maxSizeY = subject.size.y

		var icon = subject.get("theme_override_icons/checked")
		if icon:
			var iconSize = icon.get_size()

			subject.maxSize -= iconSize.x
	else:
		subject.shrink = false

	if subject.autoMaxSize:
		subject.custom_minimum_size = subject.size

	if subject.grow_horizontal == subject.GROW_DIRECTION_BEGIN:
		subject.refPos.x = subject.position.x + subject.size.x
	elif subject.grow_horizontal == subject.GROW_DIRECTION_END:
		subject.refPos.x = subject.position.x
	else:
		subject.refPos.x = subject.position.x + subject.size.x * 0.5

	if subject.grow_vertical == subject.GROW_DIRECTION_BEGIN:
		subject.refPos.y = subject.position.y + subject.size.y
	elif subject.grow_vertical == subject.GROW_DIRECTION_END:
		subject.refPos.y = subject.position.y
	else:
		subject.refPos.y = subject.position.y + subject.size.y * 0.5

	subject.add_to_group("Localized")
	subject.call_deferred("updateLocale")

static func updateText(subject: Receiver):
	if subject.translationKey == "": return

	if "text" in subject and subject.get("bbcode_enabled"):
		var newText = Util.tra(subject.translationKey)

		if subject.removeBreaks:
			newText = newText.replace("\n", "")
		if subject.capslock:
			newText = newText.to_upper()

		if subject.formatParams != null:
			newText = newText.format(subject.formatParams)

		subject.set("text", subject.prefix + newText + subject.suffix)

		if subject.shrink:
			subject.shrinkIfTooBig(subject.get("text"))

	elif "text" in subject:

		var newText = Util.tra(subject.translationKey)

		if subject.removeBreaks:
			newText = newText.replace("\n", "")
		if subject.capslock:
			newText = newText.to_upper()

		if subject.formatParams != null:
			newText = newText.format(subject.formatParams)

		var fullText = subject.prefix + newText + subject.suffix
		subject.set("text", fullText)

		if subject.shrink:
			subject.shrinkIfTooBig(fullText)

		if subject.grow_horizontal == subject.GROW_DIRECTION_BEGIN:
			subject.position.x = subject.refPos.x - subject.size.x
		elif subject.grow_horizontal == subject.GROW_DIRECTION_END:
			subject.position.x = subject.refPos.x
		else:
			subject.position.x = subject.refPos.x - subject.size.x * 0.5

		if subject.grow_vertical == subject.GROW_DIRECTION_BEGIN:
			subject.position.y = subject.refPos.y - subject.size.y
		elif subject.grow_vertical == subject.GROW_DIRECTION_END:
			subject.position.y = subject.refPos.y
		else:
			subject.position.y = subject.refPos.y - subject.size.y * 0.5

static func shrinkIfTooBig(subject: Receiver, newText):
	for path in subject.fonts:
		var font = subject.fonts[path]
		if font == null: continue
		subject.set(path, font)
		if not font is LegacyFont:
			var size_key = "normal_font_size" if path.ends_with("normal_font") else "bold_font_size" if path.ends_with("bold_font") else "font_size"
			if not subject.modern_font_sizes.has(path): subject.modern_font_sizes[path] = subject.get_theme_font_size(size_key)
			var font_size = int(subject.modern_font_sizes[path])
			for _i in subject.shrinkLimit:
				var measured = font.get_multiline_string_size(newText, HORIZONTAL_ALIGNMENT_LEFT, subject.maxSize, font_size) if subject.isAutoWrapping() else font.get_string_size(newText, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				if (subject.maxSize <= 0 or measured.x <= subject.maxSize) and (subject.maxSizeY <= 0 or measured.y <= subject.maxSizeY): break
				font_size = maxi(8, font_size - 2)
			subject.add_theme_font_size_override(size_key, font_size)
			subject.update_minimum_size()
			continue
		for i in subject.shrinkLimit:
			var textSize
			if subject.isAutoWrapping():
				textSize = font.get_wordwrap_string_size(newText, subject.maxSize)

				var s = newText.replace(" ", "\n")
				var freeHeight = font.get_wordwrap_string_size(s, 10000).y
				var constrainedHeight = font.get_wordwrap_string_size(s, subject.maxSize).y
				if constrainedHeight > freeHeight:
					textSize.x = subject.maxSize + 10
			else:
				textSize = font.get_string_size(newText, HORIZONTAL_ALIGNMENT_LEFT, -1, font.size)

			if textSize.x > subject.maxSize or textSize.y > subject.maxSizeY:
				font = Util.getSizedFont(font, - 2)
				subject.set(path, font)
			else:
				break

		if subject.anchor_left == subject.anchor_right and subject.anchor_top == subject.anchor_bottom:
			subject.size = Vector2.ZERO
		else:
			subject.update_minimum_size()

static func collectFonts(subject: Receiver):
	if "text" in subject and subject.get("bbcode_enabled"):
		for path in ["theme_override_fonts/normal_font", "theme_override_fonts/bold_font"]:
			subject.fonts[path] = subject.get(path)
	elif "text" in subject:
		subject.fonts["theme_override_fonts/font"] = subject.get("theme_override_fonts/font")
