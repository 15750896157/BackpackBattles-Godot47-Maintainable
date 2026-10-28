extends RefCounted
class_name LegacyGrid

static func used_cells(map: TileMap) -> Array:
	return map.get_used_cells(0).map(func(cell): return Vector2(cell))
static func used_cells_by_id(map: TileMap, id: int) -> Array:
	return map.get_used_cells_by_id(0, id).map(func(cell): return Vector2(cell))
static func cell_origin(map: TileMap, cell) -> Vector2:
	return map.map_to_local(Vector2i(cell)) - Vector2(map.tile_set.tile_size) * 0.5
static func cell(map: TileMap, position: Vector2) -> Vector2:
	return Vector2(map.local_to_map(position))
