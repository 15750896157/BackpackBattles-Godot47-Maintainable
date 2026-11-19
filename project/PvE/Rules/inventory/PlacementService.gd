class_name PlacementService
extends RefCounted

var db

func _init(content = null):
	db = content

func definition(id: String) -> Dictionary:
	var bag = db.get_row("bags", id)
	if not bag.is_empty():
		bag["kind"] = "bag"
		return bag
	var item = db.get_row("items", id)
	if not item.is_empty():
		item["kind"] = "item"
	return item

func is_bag(entry: Dictionary) -> bool:
	return not db.get_row("bags", str(entry.get("definition_id", ""))).is_empty()

func rotations(entry: Dictionary) -> Array:
	var def = definition(str(entry.get("definition_id", "")))
	var table = "bag_shapes" if def.get("kind") == "bag" else "item_shapes"
	var row = db.get_row(table, str(def.get("shape_id", "")))
	var result: Array = []
	for value in str(row.get("allowed_rotations", "0|90|180|270")).split("|"):
		result.append(int(value))
	return result

func rotate_cells(raw: Array, rotation: int) -> Array:
	var result: Array = []
	var minimum = Vector2i(2147483647, 2147483647)
	for value in raw:
		var point = Vector2i(value)
		for turn in range(posmod(rotation, 360) / 90):
			point = Vector2i(-point.y, point.x)
		minimum.x = mini(minimum.x, point.x)
		minimum.y = mini(minimum.y, point.y)
		result.append(point)
	for i in range(result.size()):
		result[i] -= minimum
	return result

func local_cells(entry: Dictionary) -> Array:
	var def = definition(str(entry.get("definition_id", "")))
	return rotate_cells(db.shape(str(def.get("shape_id", "")), def.get("kind") == "bag"), int(entry.get("rotation", 0)))

func cells(entry: Dictionary) -> Array:
	var result = local_cells(entry)
	var origin = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	for i in range(result.size()):
		result[i] += origin
	return result

func validate(build: Dictionary) -> Dictionary:
	if not _integer(build.get("width", 9)) or not _integer(build.get("height", 7)) or int(build.get("width", 9)) != 9 or int(build.get("height", 7)) != 7:
		return _error("grid_dimensions", "背包画布必须为 9 × 7。")
	var capacity = int(build.get("storage_capacity", 2))
	if not _integer(build.get("storage_capacity", 2)) or capacity < 2 or capacity > 4:
		return _error("storage_capacity", "仓库容量必须在 2 至 4 之间。")
	if build.get("storage", []).size() > capacity:
		return _error("storage_full", "仓库空间不足。")
	var seen: Dictionary = {}
	var occupied: Dictionary = {"bags": {}, "items": {}}
	for layer in ["bags", "items", "storage"]:
		for entry in build.get(layer, []):
			var uid = str(entry.get("uid", ""))
			if uid.is_empty() or seen.has(uid):
				return _error("duplicate_uid", "物品实例编号重复或缺失。", uid)
			seen[uid] = true
			var def = definition(str(entry.get("definition_id", "")))
			if def.is_empty():
				return _error("unknown_definition", "物品定义不存在。", uid)
			if not _integer(entry.get("x", 0)) or not _integer(entry.get("y", 0)) or not _integer(entry.get("rotation", 0)):
				return _error("integer_coordinates", "物品必须对齐整数网格。", uid)
			if not rotations(entry).has(int(entry.get("rotation", 0))):
				return _error("rotation", "该形状不支持此朝向。", uid)
			if layer == "storage":
				continue
			if (layer == "bags") != (def.get("kind") == "bag"):
				return _error("wrong_layer", "物品位于错误的逻辑层。", uid)
			var shape = cells(entry)
			if shape.is_empty():
				return _error("empty_shape", "物品形状为空。", uid)
			for point in shape:
				if point.x < 0 or point.y < 0 or point.x >= 9 or point.y >= 7:
					return _error("out_of_bounds", "物品超出背包画布。", uid)
				if occupied[layer].has(point):
					return _error("overlap", "同层物品发生重叠。", uid)
				occupied[layer][point] = uid
	for point in occupied.items:
		if not occupied.bags.has(point):
			return _error("unsupported_item", "移除或移动背包会使物品悬空。", occupied.items[point])
	return {"ok": true, "error": "", "valid_cells": occupied.bags.keys(), "bag_owners": occupied.bags, "item_occupancy": occupied.items}

func find(build: Dictionary, uid: String) -> Dictionary:
	for layer in ["bags", "items", "storage"]:
		for index in range(build.get(layer, []).size()):
			if str(build[layer][index].get("uid")) == uid:
				return {"layer": layer, "index": index, "entry": build[layer][index].duplicate(true)}
	return {}

func preview(build: Dictionary, entry: Dictionary, x: int, y: int, rotation: int) -> Dictionary:
	var candidate = build.duplicate(true)
	var old = find(candidate, str(entry.get("uid", "")))
	if not old.is_empty():
		candidate[old.layer].remove_at(old.index)
	var placed = entry.duplicate(true)
	placed["x"] = x
	placed["y"] = y
	placed["rotation"] = rotation
	candidate["bags" if is_bag(placed) else "items"].append(placed)
	var result = validate(candidate)
	result["cells"] = cells(placed)
	if result.ok:
		result["build"] = candidate
		result["entry"] = placed
	return result

func move(build: Dictionary, uid: String, x: int, y: int, rotation: int) -> Dictionary:
	var found = find(build, uid)
	if found.is_empty():
		return _error("missing_item", "找不到物品。", uid)
	var result = preview(build, found.entry, x, y, rotation)
	return _commit(build, result)

func auto_place(build: Dictionary, entry: Dictionary) -> Dictionary:
	var allowed = rotations(entry)
	var preferred = int(entry.get("rotation", 0))
	if allowed.has(preferred):
		allowed.erase(preferred)
		allowed.push_front(preferred)
	for rotation in allowed:
		for y in range(7):
			for x in range(9):
				var result = preview(build, entry, x, y, rotation)
				if result.ok:
					return _commit(build, result)
	return _error("no_placement", "没有可完整放下此物品的位置。", str(entry.get("uid", "")))

func store(build: Dictionary, entry: Dictionary) -> Dictionary:
	var candidate = build.duplicate(true)
	var old = find(candidate, str(entry.get("uid", "")))
	if not old.is_empty():
		candidate[old.layer].remove_at(old.index)
	candidate.storage.append(entry.duplicate(true))
	return _commit(build, _validated_candidate(candidate))

func remove(build: Dictionary, uid: String, to_storage: bool = false) -> Dictionary:
	var found = find(build, uid)
	if found.is_empty():
		return _error("missing_item", "找不到物品。", uid)
	if to_storage:
		return store(build, found.entry)
	var candidate = build.duplicate(true)
	candidate[found.layer].remove_at(found.index)
	var result = _validated_candidate(candidate)
	result["entry"] = found.entry
	return _commit(build, result)

func restore(build: Dictionary, uid: String) -> Dictionary:
	var found = find(build, uid)
	if found.is_empty() or found.layer != "storage":
		return _error("not_in_storage", "物品不在仓库。", uid)
	var previous = preview(build, found.entry, int(found.entry.get("x", 0)), int(found.entry.get("y", 0)), int(found.entry.get("rotation", 0)))
	if previous.ok:
		return _commit(build, previous)
	return auto_place(build, found.entry)

func swap(build: Dictionary, first_uid: String, second_uid: String) -> Dictionary:
	var first = find(build, first_uid)
	var second = find(build, second_uid)
	if first.is_empty() or second.is_empty() or first_uid == second_uid:
		return _error("invalid_swap", "交换需要两个不同的物品。")
	if first.layer != "storage" and second.layer != "storage" and first.layer != second.layer:
		return _error("wrong_layer", "背包与普通物品不能交换逻辑层。")
	var candidate = build.duplicate(true)
	var a = first.entry.duplicate(true)
	var b = second.entry.duplicate(true)
	if first.layer == "storage" and second.layer == "storage":
		candidate.storage[first.index] = b
		candidate.storage[second.index] = a
	elif first.layer == "storage" or second.layer == "storage":
		var stored = first if first.layer == "storage" else second
		var placed = second if first.layer == "storage" else first
		if is_bag(stored.entry) != is_bag(placed.entry):
			return _error("wrong_layer", "交换物品必须属于同一逻辑层。")
		var replacement = stored.entry.duplicate(true)
		replacement["x"] = placed.entry.x
		replacement["y"] = placed.entry.y
		candidate[placed.layer][placed.index] = replacement
		candidate.storage[stored.index] = placed.entry.duplicate(true)
	else:
		a["x"] = second.entry.x
		a["y"] = second.entry.y
		b["x"] = first.entry.x
		b["y"] = first.entry.y
		candidate[first.layer][first.index] = a
		candidate[second.layer][second.index] = b
	return _commit(build, _validated_candidate(candidate))

func expand_storage(build: Dictionary, capacity: int) -> Dictionary:
	if capacity < int(build.get("storage_capacity", 2)) or capacity > 4:
		return _error("storage_capacity", "仓库扩容不能缩小容量或超过 4 格。")
	var candidate = build.duplicate(true)
	candidate["storage_capacity"] = capacity
	return _commit(build, _validated_candidate(candidate))

func _validated_candidate(candidate: Dictionary) -> Dictionary:
	var result = validate(candidate)
	if result.ok:
		result["build"] = candidate
	return result

func _commit(build: Dictionary, result: Dictionary) -> Dictionary:
	if result.ok:
		var candidate = result.build
		build.clear()
		build.merge(candidate, true)
	return result

func _integer(value) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))

func _error(code: String, message: String, uid: String = "") -> Dictionary:
	return {"ok": false, "error": code, "message": message, "code": code, "uid": uid}
