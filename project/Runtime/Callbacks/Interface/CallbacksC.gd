extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCursor:
	const Receiver = preload("res://Interface/Cursor.gd")

	static func _process(subject: Receiver, _delta: float) -> void :
		var texIndex = Game.CursorTypes.DEFAULT

		if Game.hoveredItems.is_empty() and not Game.draggedItem:
			if Input.get_current_cursor_shape() == Input.CURSOR_POINTING_HAND:
				if Game.left_click:
					texIndex = Game.CursorTypes.CLICKABLE_CLICKED
				else:
					texIndex = Game.CursorTypes.CLICKABLE
			else:
				if Game.left_click:
					texIndex = Game.CursorTypes.CLICKED
				else:
					texIndex = Game.CursorTypes.DEFAULT

		else:
			if Game.left_click:
				texIndex = Game.CursorTypes.GRABBED
			else:
				texIndex = Game.CursorTypes.GRABBABLE

		subject.sprite.position = - Game.getCursorOffset(texIndex)
		subject.sprite.texture = Game.scaledCursors[texIndex]

		subject.sprite.scale.y = subject.sprite.scale.x
		subject.position = subject.get_global_mouse_position()
