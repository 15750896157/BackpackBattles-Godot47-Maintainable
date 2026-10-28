extends FontVariation
class_name LegacyFont

@export var size: int = 16:
	set(value):
		size = value
		emit_changed()
@export var outline_size: int = 0:
	set(value):
		outline_size = value
		emit_changed()
@export var outline_color: Color = Color.BLACK:
	set(value):
		outline_color = value
		emit_changed()
@export var use_filter: bool = true
@export var use_mipmaps: bool = false
var font_data: FontFile:
	get: return base_font as FontFile
	set(value): base_font = value
func add_fallback(font: Font) -> void:
	if font and font != self and not font in fallbacks:
		var updated = fallbacks.duplicate()
		updated.append(font)
		fallbacks = updated
func get_fallback_count() -> int: return fallbacks.size()
func get_fallback(index: int) -> Font: return fallbacks[index]
func remove_fallback(index: int) -> void:
	if index >= 0 and index < fallbacks.size():
		var updated = fallbacks.duplicate()
		updated.remove_at(index)
		fallbacks = updated

func get_wordwrap_string_size(text: String, width: float) -> Vector2:
	return get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size)

func update_changes() -> void:
	emit_changed()
