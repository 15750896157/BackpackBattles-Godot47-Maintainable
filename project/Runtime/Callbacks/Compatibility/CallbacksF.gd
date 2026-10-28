extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForFontSizeBinder:
	const Receiver = preload("res://Compatibility/FontSizeBinder.gd")

	static func _bind_id(subject: Receiver, node_id: int) -> void:
		var node = instance_from_id(node_id)
		if not is_instance_valid(node) or not node is Control: return
		var font_keys = subject.KEYS.keys() if node is RichTextLabel else ["font"]
		for key in font_keys:
			var font = node.get_theme_font(key)
			if not font is LegacyFont: continue
			var font_id = font.get_instance_id()
			# IDs avoid retaining a Font in its own callback or calling a freed node.
			var callback = subject._apply_ids.bind(node_id, key, font_id)
			if not font.changed.is_connected(callback):
				font.changed.connect(callback)
				var disconnect_callback = subject._unbind.bind(font_id, callback)
				if not node.tree_exiting.is_connected(disconnect_callback):
					node.tree_exiting.connect(disconnect_callback, subject.CONNECT_ONE_SHOT)
			subject._apply_ids(node_id, key, font_id)

	static func _apply_ids(subject: Receiver, node_id: int, key: String, font_id: int) -> void:
		var node = instance_from_id(node_id)
		var font = instance_from_id(font_id)
		if not is_instance_valid(node) or not is_instance_valid(font): return
		if node.get_theme_font(key) != font: return
		node.add_theme_font_size_override(subject.KEYS[key], font.size)
		if key == "font" or key == "normal_font":
			node.add_theme_constant_override("outline_size", font.outline_size)
			node.add_theme_color_override("font_outline_color", font.outline_color)
