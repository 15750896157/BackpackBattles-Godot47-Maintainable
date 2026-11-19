extends Node2D
## Display cells only. Placement validation still reads authoritative bag cells.
var build: Dictionary = {}
var cell_texture: Texture2D
var empty_texture: Texture2D
var guide_texture: Texture2D
var active_cells: Dictionary = {}
var showing_empty = false
var seams: Dictionary = {}
var specials:Array=[]
func _process(_delta):
	var value = is_instance_valid(Game.draggedItem) and Game.draggedItem.isBag()
	if value != showing_empty: showing_empty = value; queue_redraw()
func configure(data: Dictionary):
	if data == build: return
	build = data.duplicate(true)
	active_cells.clear()
	for bag in build.get("bags", []):
		for cell in Expedition.flow.placement.cells(bag): active_cells[Vector2i(cell)] = true
	specials=Expedition.flow.spatial.special_cells(build)
	queue_redraw()
func _draw():
	if cell_texture == null: return
	for y in int(build.get("height", 7)):
		for x in int(build.get("width", 9)):
			var active = active_cells.has(Vector2i(x, y))
			var tile = Rect2(Vector2(x,y)*80.0+Vector2(3,3),Vector2(74,74))
			if not active and not showing_empty:
				if guide_texture != null:
					draw_texture_rect(guide_texture,tile,false,Color(1,1,1,0.21))
				continue
			var image=cell_texture if active else empty_texture
			if image!=null:draw_texture_rect(image,tile,false,Color(1,1,1,0.24 if active else 0.15))
			# Fine translucent seams reveal the leather instead of a white tile fill.
			draw_style_box(_seam(active),tile)
	for special in specials:
		var rect=Rect2(Vector2(special.cell)*80.0+Vector2(5,5),Vector2(70,70))
		draw_rect(rect,Color(1,0.78,0.3,0.42),false,2)
		if special.type=="star_cell":
			var points=PackedVector2Array()
			for index in 10:
				var angle=-PI/2+index*PI/5
				points.append(rect.position+Vector2(12,12)+Vector2(cos(angle),sin(angle))*(9 if index%2==0 else 4))
			draw_colored_polygon(points,Color(1,0.85,0.34,0.72))

func _seam(active: bool) -> StyleBoxFlat:
	if seams.has(active): return seams[active]
	var seam = StyleBoxFlat.new()
	seam.bg_color = Color(0.24,0.17,0.10,0.025) if active else Color(0.72,0.61,0.40,0.045)
	seam.border_color = Color(0.88,0.76,0.51,0.20) if active else Color(0.75,0.66,0.48,0.24)
	seam.set_border_width_all(1); seam.set_corner_radius_all(5)
	seams[active] = seam
	return seam
