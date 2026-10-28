extends Node

const KEYS = {"font": "font_size", "normal_font": "normal_font_size", "bold_font": "bold_font_size", "italics_font": "italics_font_size", "bold_italics_font": "bold_italics_font_size", "mono_font": "mono_font_size"}

func _ready() -> void:
	get_tree().node_added.connect(_node_added)
	_scan.call_deferred(get_tree().root)

func _scan(node: Node) -> void:
	_bind_id(node.get_instance_id())
	for child in node.get_children(): _scan(child)

func _node_added(node: Node) -> void:
	_bind_id.call_deferred(node.get_instance_id())

func _bind_id(node_id: int) -> void:
	load("res://Runtime/Callbacks/Compatibility/CallbacksF.gd").ForFontSizeBinder._bind_id(self, node_id)

func _unbind(font_id: int, callback: Callable) -> void:
	var font = instance_from_id(font_id)
	if is_instance_valid(font) and font.changed.is_connected(callback):
		font.changed.disconnect(callback)

func _apply_ids(node_id: int, key: String, font_id: int) -> void:
	load("res://Runtime/Callbacks/Compatibility/CallbacksF.gd").ForFontSizeBinder._apply_ids(self, node_id, key, font_id)

