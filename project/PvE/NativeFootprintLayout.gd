extends RefCounted
## Read-only measurements of recovered artwork. Never replace, crop, mirror or
## rotate an imported texture; only the saved grid direction rotates the item.

var pictures: Dictionary = {}
const MAX_PICTURES = 96

func bounds(cells: Array) -> Vector2:
	var result = Vector2.ZERO
	for cell in cells: result = result.max(Vector2(cell) + Vector2.ONE)
	return result

func texture_points(sprite: Sprite2D) -> Array[Vector2]:
	var image = sprite.texture.get_image()
	if image == null: return []
	if image.is_compressed(): image.decompress()
	if sprite.region_enabled:
		image = image.get_region(Rect2i(sprite.region_rect))
	elif sprite.hframes > 1 or sprite.vframes > 1:
		var frame_size = image.get_size() / Vector2i(sprite.hframes, sprite.vframes)
		image = image.get_region(Rect2i(sprite.frame_coords * frame_size, frame_size))
	var used = image.get_used_rect()
	var result: Array[Vector2] = []
	var stride = maxi(1, ceili(sqrt(float(used.size.x * used.size.y) / 1500.0)))
	for y in range(used.position.y + stride / 2, used.end.y, stride):
		for x in range(used.position.x + stride / 2, used.end.x, stride):
			if image.get_pixel(x, y).a < 0.25: continue
			var point = Vector2(image.get_width() - x - 0.5 if sprite.flip_h else x + 0.5, image.get_height() - y - 0.5 if sprite.flip_v else y + 0.5)
			result.append(sprite.get_rect().position + point)
	return result

func measured(points: Array[Vector2]) -> Dictionary:
	var minimum = Vector2(INF, INF)
	var maximum = Vector2(-INF, -INF)
	var centroid = Vector2.ZERO
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
		centroid += point
	return {"points": points, "minimum": minimum, "size": maximum - minimum, "center": (minimum + maximum) * 0.5, "centroid": centroid / maxi(1, points.size()), "layouts": {}}

func geometry(item) -> Dictionary:
	if item.has_meta("pve_native_geometry"): return item.get_meta("pve_native_geometry")
	var sprites: Array = [item.sprite]
	for child in item.sprite.find_children("*", "Sprite2D", true, false):
		if child.is_visible_in_tree() and child.texture != null and child.self_modulate.a > 0.05: sprites.append(child)
	var points: Array[Vector2] = []
	var original_scale: Vector2 = item.get_meta("pve_original_scale")
	for sprite in sprites:
		var relative: Transform2D = item.sprite.global_transform.affine_inverse() * sprite.global_transform
		for point in texture_points(sprite): points.append(original_scale * (relative * point))
	var result = measured(points)
	item.set_meta("pve_native_geometry", result)
	return result

func picture(texture: Texture2D) -> Dictionary:
	var key = texture.get_instance_id()
	if pictures.has(key): return pictures[key]
	var temporary = Sprite2D.new()
	temporary.texture = texture
	var points = texture_points(temporary)
	temporary.free()
	var result = measured(points)
	if pictures.size() >= MAX_PICTURES: pictures.erase(pictures.keys()[0])
	pictures[key] = result
	return result

func rectangle(geometry: Dictionary, size: Vector2) -> Dictionary:
	var factor = 0.94 * minf(size.x / maxf(1.0, geometry.size.x), size.y / maxf(1.0, geometry.size.y))
	return {"factor": factor, "origin": size * 0.5 - geometry.center * factor, "mode": "upright_rectangle"}

func fit(geometry: Dictionary, cells: Array) -> Dictionary:
	var key = str(cells)
	if geometry.layouts.has(key): return geometry.layouts[key]
	var occupied: Dictionary = {}
	var centroid = Vector2.ZERO
	for cell in cells:
		occupied[Vector2i(cell)] = true
		centroid += (Vector2(cell) + Vector2(0.5, 0.5)) * 80.0
	centroid /= cells.size()
	var centers = [centroid, bounds(cells) * 40.0]
	for cell in cells: centers.append((Vector2(cell) + Vector2(0.5, 0.5)) * 80.0)
	var size = bounds(cells) * 80.0
	var maximum = minf(size.x / maxf(1.0, geometry.size.x), size.y / maxf(1.0, geometry.size.y))
	var result: Dictionary = {}
	for proportion in [0.92, 0.86, 0.80, 0.74, 0.68, 0.62, 0.56, 0.50, 0.44, 0.38, 0.32, 0.26, 0.20, 0.14]:
		var factor = maximum * proportion
		var best_distance = INF
		for center in centers:
			for offset in [Vector2.ZERO, Vector2(-12, 0), Vector2(12, 0), Vector2(0, -12), Vector2(0, 12)]:
				var origin: Vector2 = center + offset - geometry.centroid * factor
				var outside = false
				for point in geometry.points:
					if not occupied.has(Vector2i(((origin + point * factor) / 80.0).floor())):
						outside = true; break
				if outside: continue
				var distance = (center + offset).distance_squared_to(centroid)
				if distance >= best_distance: continue
				best_distance = distance
				result = {"factor": factor, "origin": origin, "mode": "upright_occupied_union"}
		if not result.is_empty(): break
	if result.is_empty():
		var factor = 70.0 / maxf(geometry.size.x, geometry.size.y)
		result = {"factor": factor, "origin": (Vector2(cells[0]) + Vector2(0.5, 0.5)) * 80.0 - geometry.center * factor, "mode": "upright_single_cell"}
	geometry.layouts[key] = result
	return result
