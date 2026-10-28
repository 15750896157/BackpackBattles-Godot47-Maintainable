extends Node2D
## Preserve valid/invalid placement feedback after retiring the old tile artwork.
var was_dragging: bool = false
func _process(_delta):
	var dragging = is_instance_valid(Game.draggedItem)
	if dragging or was_dragging: queue_redraw()
	was_dragging = dragging
func _draw():
	if not is_instance_valid(Game.draggedItem) or Game.state != Game.State.Shop: return
	var inventory = get_parent()
	for cell in inventory.curHovered:
		var id = inventory.tilemap.get_cell_source_id(0, Vector2i(cell))
		var good = id in [inventory.Tile.HoveredOK, inventory.Tile.HoveredOK_Bag]
		var color = Color(0.25, 1.0, 0.48, 0.8) if good else Color(1.0, 0.26, 0.22, 0.8)
		var rect = Rect2(Vector2(cell) * 80.0 + Vector2(3, 3), Vector2(74, 74))
		draw_rect(rect, Color(color, 0.2), true)
		draw_rect(rect, color, false, 2.0)
