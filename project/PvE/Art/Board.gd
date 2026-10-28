extends Node2D
## Display cells only. Placement validation still reads authoritative bag cells.
var build: Dictionary = {}
var cell_texture: Texture2D
var active_cells: Dictionary = {}
var showing_empty = false
var seams: Dictionary = {}
func _process(_delta):
	var value = is_instance_valid(Game.draggedItem) and Game.draggedItem.isBag()
	if value != showing_empty: showing_empty = value; queue_redraw()
func configure(data: Dictionary):
	if data == build: return
	build = data.duplicate(true)
	active_cells.clear()
	for bag in build.get("bags", []):
		for cell in Expedition.flow.placement.cells(bag): active_cells[Vector2i(cell)] = true
	queue_redraw()
func _draw():
	if cell_texture == null: return
	for y in int(build.get("height", 7)):
		for x in int(build.get("width", 9)):
			var active = active_cells.has(Vector2i(x, y))
			if not active and not showing_empty: continue
			var tile = Rect2(Vector2(x,y)*80.0+Vector2(3,3),Vector2(74,74))
			# Fine translucent seams reveal the leather instead of a white tile fill.
			draw_style_box(_seam(active),tile)

func _seam(active: bool) -> StyleBoxFlat:
	if seams.has(active): return seams[active]
	var seam = StyleBoxFlat.new()
	seam.bg_color = Color(0.24,0.17,0.10,0.025) if active else Color(0.72,0.61,0.40,0.045)
	seam.border_color = Color(0.88,0.76,0.51,0.20) if active else Color(0.75,0.66,0.48,0.24)
	seam.set_border_width_all(1); seam.set_corner_radius_all(5)
	seams[active] = seam
	return seam
