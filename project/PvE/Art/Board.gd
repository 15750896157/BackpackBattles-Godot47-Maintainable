extends Node2D
## 只负责显示格子；放置校验仍然读取权威的背包格数据。
## 层级自下而上：背包 → 9x7 网格（ui_cell_slot）→ 空位/占用方块 → 物品。
var build: Dictionary = {}
## 第三层：有物品的背包位使用这张方块。
var filled_texture: Texture2D
## 第三层：空背包位使用这张方块。
var empty_texture: Texture2D
## 第二层：9x7 网格底图，铺在背包上方、方块下方。
var slot_texture: Texture2D
## 背包实际占用的格子；方块只画在这些格子上。
var active_cells: Dictionary = {}
var occupied_cells: Dictionary = {}
var specials:Array=[]
func configure(data: Dictionary):
	if data == build: return
	build = data.duplicate(true)
	active_cells.clear()
	occupied_cells.clear()
	for bag in build.get("bags", []):
		for cell in Expedition.flow.placement.cells(bag): active_cells[Vector2i(cell)] = true
	for entry in build.get("items", []):
		for cell in Expedition.flow.placement.cells(entry): occupied_cells[Vector2i(cell)] = true
	specials=Expedition.flow.spatial.special_cells(build)
	queue_redraw()
func _draw():
	# 第二层：9x7 网格盖在背包上，贴图按原始像素落在每个格子里，不做缩放。
	if slot_texture != null:
		var slot_offset = _offset(slot_texture)
		for y in int(build.get("height", 7)):
			for x in int(build.get("width", 9)):
				draw_texture(slot_texture, Vector2(x, y) * 80.0 + slot_offset)
	# 第三层：只在背包占用的格子上贴方块——有物品用占用方块，空位用空位方块。
	for cell in active_cells.keys():
		var image: Texture2D = filled_texture if occupied_cells.has(cell) else empty_texture
		if image == null: continue
		draw_texture(image, Vector2(cell) * 80.0 + _offset(image))
	for special in specials:
		if str(special.type) == "bag_cell": continue
		var rect=Rect2(Vector2(special.cell)*80.0+Vector2(5,5),Vector2(70,70))
		draw_rect(rect,Color(1,0.78,0.3,0.42),false,2)
		if special.type=="star_cell":
			var points=PackedVector2Array()
			for index in 10:
				var angle=-PI/2+index*PI/5
				points.append(rect.position+Vector2(12,12)+Vector2(cos(angle),sin(angle))*(9 if index%2==0 else 4))
			draw_colored_polygon(points,Color(1,0.85,0.34,0.72))

func _offset(texture: Texture2D) -> Vector2:
	# 80 单位格子里居中摆放，贴图尺寸原样保留。
	return (Vector2(80, 80) - texture.get_size()) * 0.5
