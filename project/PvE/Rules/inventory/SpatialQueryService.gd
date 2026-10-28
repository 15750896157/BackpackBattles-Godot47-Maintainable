class_name SpatialQueryService
extends RefCounted

var db
var placement

func _init(content = null):
	db = content
	placement = PlacementService.new(content)

func cells(entry: Dictionary) -> Array:
	return placement.cells(entry)

func tags(entry: Dictionary) -> Array:
	var row = db.get_row("items", str(entry.get("definition_id", "")))
	return str(row.get("tags", "")).split("|", false)

func bag_owners(build: Dictionary, uid: String) -> Array:
	var found = placement.find(build, uid)
	if found.is_empty() or found.layer == "storage":
		return []
	var source_cells = cells(found.entry)
	var result: Array = []
	for bag in build.get("bags", []):
		if _intersects(source_cells, cells(bag)):
			result.append(str(bag.uid))
	return result

func special_cells(build: Dictionary, uid: String = "") -> Array:
	var result: Array = []
	var filter_cells: Array = []
	if not uid.is_empty():
		var found = placement.find(build, uid)
		if found.is_empty() or found.layer == "storage":
			return []
		filter_cells = cells(found.entry)
	for bag in build.get("bags", []):
		var def = db.get_row("bags", str(bag.definition_id))
		var raw = db.shape(str(def.get("shape_id", "")), true)
		var rotated = placement.rotate_cells(raw, int(bag.get("rotation", 0)))
		for token in str(def.get("special_cells", "")).split("|", false):
			var parts = token.split(":")
			if parts.size() != 2:
				continue
			var index = raw.find(Vector2i(int(parts[0]), int(parts[1])))
			if index < 0:
				continue
			var point = rotated[index] + Vector2i(int(bag.x), int(bag.y))
			if uid.is_empty() or filter_cells.has(point):
				result.append({"cell": point, "bag_uid": str(bag.uid), "type": str(def.get("special_cell_type", "none")), "effect": str(def.get("special_effect", "")), "stackable": bool(def.get("special_stackable", false))})
	return result

func targets(build: Dictionary, source_uid: String, template_id: String, tag_filter: String = "") -> Array:
	return query(build, source_uid, template_id, tag_filter).uids

func active_special_effects(build: Dictionary, uid: String) -> Array:
	var found = placement.find(build, uid)
	if found.is_empty() or found.layer != "items":
		return []
	var occupied = cells(found.entry)
	var owners = bag_owners(build, uid)
	var result: Array = []
	for special in special_cells(build):
		if not owners.has(str(special.bag_uid)):
			continue
		var affected = occupied.has(special.cell)
		if special.type == "star_cell" and not affected:
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if occupied.has(special.cell + offset):
					affected = true
					break
		if affected:
			result.append(special.duplicate(true))
	return result

func relations(build: Dictionary, source_uid: String, template_id: String, tag_filter: String = "") -> Array:
	return targets(build, source_uid, template_id, tag_filter)

func query(build: Dictionary, source_uid: String, template_id: String, tag_filter: String = "") -> Dictionary:
	var source = placement.find(build, source_uid)
	var result = {"uids": [], "cells": [], "template_id": template_id}
	if source.is_empty() or source.layer != "items":
		return result
	var template = db.get_row("spatial_templates", template_id)
	if template.is_empty():
		return result
	var relation = str(template.get("relation_type", template_id))
	var source_cells = cells(source.entry)
	var region: Array = []
	var source_bags = bag_owners(build, source_uid)
	var center = _center(source_cells)
	if relation == "none":
		region = source_cells.duplicate()
	elif relation in ["adjacent_4", "adjacent_8"]:
		var offsets = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		if relation == "adjacent_8":
			offsets.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
		for point in source_cells:
			for offset in offsets:
				_add_cell(region, point + offset, source_cells)
	elif relation == "front":
		var direction = Vector2i.RIGHT
		for turn in range(int(posmod(int(source.entry.get("rotation", 0)), 360) / 90)):
			direction = Vector2i(-direction.y, direction.x)
		for point in source_cells:
			# Cast from exposed leading edges, not through the item's own shape.
			if source_cells.has(point + direction):
				continue
			for distance in range(1, int(template.get("range", 1)) + 1):
				_add_cell(region, point + direction * distance, source_cells)
	elif relation == "same_row":
		for x in range(9):
			region.append(Vector2i(x, center.y))
	elif relation == "same_column":
		for y in range(7):
			region.append(Vector2i(center.x, y))
	elif relation == "star_cell":
		for special in special_cells(build):
			if special.type != "star_cell" or not source_bags.has(special.bag_uid):
				continue
			_add_cell(region, special.cell)
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				_add_cell(region, special.cell + offset)
	elif relation == "same_bag":
		for bag in build.get("bags", []):
			if source_bags.has(str(bag.uid)):
				for point in cells(bag):
					_add_cell(region, point)
	elif relation == "global_same_tag":
		for target in build.get("items", []):
			if (not tag_filter.is_empty() and tags(target).has(tag_filter)) or (tag_filter.is_empty() and _intersects(tags(source.entry), tags(target))):
				for point in cells(target):
					_add_cell(region, point)
	result.cells = region
	for target in build.get("items", []):
		if str(target.uid) == source_uid:
			continue
		if not tag_filter.is_empty() and not tags(target).has(tag_filter):
			continue
		var matches = _intersects(region, cells(target))
		if relation == "same_row":
			matches = _center(cells(target)).y == center.y
		elif relation == "same_column":
			matches = _center(cells(target)).x == center.x
		elif relation == "same_bag":
			matches = _intersects(source_bags, bag_owners(build, str(target.uid)))
		if matches:
			result.uids.append(str(target.uid))
	result.uids.sort()
	return result

func condition(build: Dictionary, source_uid: String, condition_id: String, params = {}, target_uid: String = "") -> bool:
	var p = params if params is Dictionary else _params(str(params))
	var source = placement.find(build, source_uid)
	var target = placement.find(build, target_uid)
	var result = false
	match condition_id:
		"always":
			result = true
		"source_has_tag":
			result = not source.is_empty() and tags(source.entry).has(str(p.get("tag", p.get("value", ""))))
		"target_has_tag":
			result = not target.is_empty() and target.layer == "items" and tags(target.entry).has(str(p.get("tag", p.get("value", ""))))
		"spatial_target_count":
			var list = targets(build, source_uid, str(p.get("template", p.get("spatial_template_id", "adjacent_4"))), str(p.get("tag", "")))
			result = _count_matches(list.size(), p)
		"build_tag_count":
			var count = 0
			var tag = str(p.get("tag", ""))
			for entry in build.get("items", []):
				if tag.is_empty() or tags(entry).has(tag):
					count += 1
			result = _count_matches(count, p)
		"no_spatial_tag":
			result = targets(build, source_uid, str(p.get("template", "adjacent_4")), str(p.get("tag", ""))).is_empty()
		"distinct_adjacent_tags":
			var distinct: Dictionary = {}
			for uid in targets(build, source_uid, str(p.get("template", "adjacent_4"))):
				for tag in tags(placement.find(build, uid).entry):
					distinct[tag] = true
			result = _count_matches(distinct.size(), p)
	return not result if bool(p.get("not", p.get("negative", false))) else result

func derived(build: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in build.get("items", []):
		var relations: Dictionary = {}
		for template in db.rows("spatial_templates"):
			relations[str(template.id)] = targets(build, str(item.uid), str(template.id))
		result[str(item.uid)] = {"cells": cells(item), "bags": bag_owners(build, str(item.uid)), "special_cells": active_special_effects(build, str(item.uid)), "relations": relations}
	return result

func _center(points: Array) -> Vector2i:
	var total = Vector2.ZERO
	for point in points:
		total += Vector2(point)
	return Vector2i(floor(total.x / maxi(points.size(), 1)), floor(total.y / maxi(points.size(), 1)))

func _add_cell(region: Array, point: Vector2i, excluded: Array = []) -> void:
	if point.x >= 0 and point.y >= 0 and point.x < 9 and point.y < 7 and not excluded.has(point) and not region.has(point):
		region.append(point)

func _intersects(a: Array, b: Array) -> bool:
	for value in a:
		if b.has(value):
			return true
	return false

func _count_matches(count: int, p: Dictionary) -> bool:
	if p.has("max") and count > int(p.max):
		return false
	if p.has("equals") and count != int(p.equals):
		return false
	return count >= int(p.get("min", p.get("value", 0 if p.has("max") or p.has("equals") else 1)))

func _params(raw: String) -> Dictionary:
	var result: Dictionary = {}
	for pair in raw.split("|", false):
		var split = pair.split(":", true, 1)
		if split.size() == 2:
			var value = str(split[1])
			if value in ["true", "false"]:
				result[split[0]] = value == "true"
			elif value.is_valid_int():
				result[split[0]] = int(value)
			else:
				result[split[0]] = value
		else:
			result["value"] = pair
	return result
