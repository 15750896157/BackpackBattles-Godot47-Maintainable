extends Control
## A read-only geometry diagram, using the rules service for rotated footprints.
var cells: Array = []
var effects: Dictionary = {}
var turn = 0
var known = true
func configure(id: String, rotation: int, discovered: bool, occupied_cells: Array, affected_cells: Dictionary):
	turn = rotation
	known = discovered
	cells = occupied_cells
	effects = affected_cells
	set_meta("blueprint_definition",id);set_meta("blueprint_rotation",rotation);queue_redraw()
func fill_art(id: String, epoch: int, base_cells: Array):
	var image = await Expedition.bindings.texture_async(id)
	if epoch != Expedition.popup_epoch or not is_instance_valid(self) or is_queued_for_deletion() or image == null:return
	var layout=Expedition.bridge.footprint_layout.fit(Expedition.bridge.footprint_layout.picture(image),base_cells)
	if layout.is_empty():return
	var base_size=Expedition.bridge.footprint_layout.bounds(base_cells)
	var rotated_bounds=Vector2i.ZERO
	for cell in cells:rotated_bounds=rotated_bounds.max(Vector2i(cell)+Vector2i.ONE)
	var minimum=Vector2(INF,INF);var angle=deg_to_rad(turn)
	for corner in [Vector2.ZERO,Vector2(base_size.x,0),base_size,Vector2(0,base_size.y)]:minimum=minimum.min(corner.rotated(angle))
	var step=minf(size.x,size.y)/7.0
	var icon=Sprite2D.new();icon.texture=image;icon.scale=Vector2.ONE*float(layout.factor)*step/80.0
	icon.position=(Vector2(layout.origin).rotated(angle)/80.0-minimum+Vector2(Vector2i((7-rotated_bounds.x)/2,(7-rotated_bounds.y)/2)))*step
	icon.rotation=angle
	if not known:icon.modulate=Color(0.12,0.10,0.08)
	add_child(icon)
func _draw():
	if cells.is_empty():return
	var bounds=Vector2i.ZERO
	for cell in cells:bounds=bounds.max(Vector2i(cell)+Vector2i.ONE)
	var offset=Vector2i((7-bounds.x)/2,(7-bounds.y)/2)
	var step=minf(size.x,size.y)/7.0
	for y in 7:
		for x in 7:
			var p=Vector2i(x,y)-offset;var occupied=cells.has(p)
			var rect=Rect2(Vector2(x,y)*step+Vector2(2,2),Vector2.ONE*(step-4))
			var style=StyleBoxFlat.new();style.set_corner_radius_all(5);style.set_border_width_all(1)
			style.bg_color=Color("715034") if occupied else Color(0.46,0.34,0.19,0.10)
			if effects.has(p) and known:style.bg_color=Color(0.27,0.54,0.31,0.42)
			style.border_color=Color(0.32,0.23,0.13,0.35);draw_style_box(style,rect)
