extends RefCounted
## Coordinates are authored on the supplied 1920 x 1080 reference canvas.
## Only presentation is built here; callbacks retain the existing game services.
const ROOT = "res://Art/Reference20261102/"
const INK = Color("513c26")
const PAPER = Color("fff1cc")
## One caption ladder for every button in the game. Callers ask for a size,
## the canvas snaps it to the nearest ladder step so text never drifts.
const FONT_STEPS = [96, 80, 72, 64, 56, 48, 44, 40, 36, 32, 28, 24, 20, 16]

static func font_step(size: int) -> int:
	for step in FONT_STEPS:
		if step <= size: return step
	return FONT_STEPS[FONT_STEPS.size() - 1]

## Chinese glyphs sit a couple of pixels low inside Godot's centred line box.
## Lift the label box by a small, size-proportional amount so the visible text
## lands on the visual centre instead of the metric centre.
static func caption_lift(size: int) -> float:
	return float(maxi(1, roundi(float(size) * 0.055)))

## Idempotent: safe to call on every refresh tick, only the delta is applied.
static func center_label(label: Label) -> void:
	if label == null: return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var size := label.get_theme_font_size("font_size")
	var want := caption_lift(size)
	var applied := float(label.get_meta("caption_lift", 0.0))
	if not is_equal_approx(want, applied):
		label.position.y += applied - want
		label.set_meta("caption_lift", want)

static func path(key: String) -> String:
	var replacement=preload("res://PvE/Art/SuppliedArt.gd").ui_path(key)
	return replacement if not replacement.is_empty() else ROOT + key + ".png"

static func paths(keys: Array) -> Array:
	return keys.map(func(key): return path(key))

static func texture(key: String) -> Texture2D:
	return AssetStream.resources.get(path(key))

static func picture(parent: Node, key: String, rect: Rect2, exact: bool = false) -> TextureRect:
	var node = TextureRect.new()
	node.name = "Ref_" + key
	node.texture = texture(key)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE if exact else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position; node.size = rect.size
	parent.add_child(node)
	node.set_meta("reference_rect", rect)
	return node

static func text(parent: Node, value: String, rect: Rect2, size: int = 28, color: Color = INK, outline: int = 0) -> Label:
	var label = Label.new()
	label.position = rect.position; label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bind_text(label, value, rect.size, size, color, outline)
	parent.add_child(label)
	center_label(label)
	return label

static func bind_text(label: Label, value: String, extent: Vector2, size: int, color: Color, outline: int) -> void:
	label.text = value
	label.add_theme_font_override("font", Expedition.ui_font)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var lines = value.split("\n")
	var fitted = font_step(size)
	var smallest = FONT_STEPS[FONT_STEPS.size() - 1]
	while fitted > smallest:
		var width = 0.0
		for line in lines: width = maxf(width, Expedition.ui_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x)
		if width <= extent.x - 8 and Expedition.ui_font.get_height(fitted) * lines.size() <= extent.y: break
		fitted = font_step(fitted - 1)
	label.add_theme_font_size_override("font_size", fitted)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("734b2d"))
	label.add_theme_constant_override("outline_size", outline)

static func button(parent: Node, key: String, rect: Rect2, callback: Callable, caption: String = "", size: int = 36) -> TextureButton:
	var node = TextureButton.new()
	node.name = "RefAction_" + key
	node.texture_normal = texture(key)
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position; node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.focus_mode = Control.FOCUS_ALL
	parent.add_child(node)
	bind_button(node, rect, callback, caption, size)
	return node

static func bind_button(node: TextureButton, rect: Rect2, callback: Callable, caption: String, size: int) -> void:
	if not caption.is_empty(): text(node, caption, Rect2(Vector2.ZERO, rect.size), size, PAPER, 4)
	node.set_meta("reference_rect", rect)
	node.pressed.connect(callback)
	node.set_meta("action_caption",caption)
	node.mouse_entered.connect(func(): feedback(node, Color(1.08, 1.06, 1.0)))
	node.mouse_exited.connect(func(): feedback(node, Color.WHITE))
	node.button_down.connect(func(): node.self_modulate = Color(0.82, 0.82, 0.82))
	node.button_up.connect(func(): node.self_modulate = Color.WHITE)

static func feedback(node: Control, tint: Color):
	if not is_instance_valid(node): return
	var previous = node.get_meta("reference_feedback") if node.has_meta("reference_feedback") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	var tween = node.create_tween().set_ignore_time_scale(true)
	node.set_meta("reference_feedback", tween)
	tween.tween_property(node, "modulate", tint, 0.1)

static func zone(parent: Node, rect: Rect2, callback: Callable, title: String = "") -> Button:
	var node = Button.new()
	node.position = rect.position; node.size = rect.size
	node.tooltip_text = title
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]: node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	parent.add_child(node); node.pressed.connect(callback)
	return node

static func fade_in(root: Control):
	root.modulate.a = 0.0
	var tween = root.create_tween().set_ignore_time_scale(true)
	tween.tween_property(root, "modulate:a", 1.0, 0.08 if Expedition.preferences.values.reduce_motion else 0.18)
