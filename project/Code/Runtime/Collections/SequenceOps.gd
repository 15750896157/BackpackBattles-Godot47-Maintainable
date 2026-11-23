extends RefCounted
## Pure collection operations. They never depend on scene or singleton state.

static func lookup(values: Array, index: int, fallback = null):
	return fallback if index >= values.size() else values[index]

static func nested_value(values: Array, indices: Array, fallback = null):
	var current = values
	for index in indices:
		if index >= current.size():
			return fallback
		current = current[index]
	return current

static func positions(values: Array, needle) -> Array:
	var result: Array = []
	var cursor = values.find(needle)
	while cursor >= 0:
		result.append(cursor)
		cursor = values.find(needle, cursor + 1)
	return result

static func distinct(values: Array) -> Array:
	var seen: Dictionary = {}
	for value in values:
		seen[value] = true
	return seen.keys()

static func has_duplicates(values: Array) -> bool:
	return distinct(values).size() != values.size()

static func duplicate_count(values: Array) -> int:
	return values.size() - distinct(values).size()

static func non_null(values: Array) -> Array:
	return values.filter(func(value): return value != null)

static func multiset_difference(values: Array, removed: Array) -> Array:
	var remaining: Dictionary = {}
	for value in removed:
		remaining[value] = remaining.get(value, 0) + 1
	return values.filter(func(value):
		if remaining.get(value, 0) == 0:
			return true
		remaining[value] -= 1
		return false)

static func reject_keys(values: Array, rejected: Dictionary) -> Array:
	return values.filter(func(value): return not rejected.has(value))

static func flatten_once(groups: Array) -> Array:
	return groups.reduce(func(result, group):
		result.append_array(group)
		return result, [])

static func inverted(values: Dictionary) -> Dictionary:
	var pairs: Dictionary = {}
	for key in values:
		pairs[values[key]] = key
	return pairs

static func accumulate(counts: Dictionary, key, delta = 1, initial = 0) -> int:
	counts[key] = counts.get(key, initial) + delta
	return counts[key]

static func subtract(counts: Dictionary, key, delta = 1) -> int:
	var remainder = counts.get(key, 0) - delta
	if remainder > 0:
		counts[key] = remainder
	else:
		counts.erase(key)
	return remainder

static func merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		accumulate(target, key, source[key])

static func bucket_append(groups: Dictionary, key, value) -> void:
	if not groups.has(key):
		groups[key] = []
	groups[key].append(value)

static func _drop_empty(groups: Dictionary, key) -> void:
	if groups[key].is_empty():
		groups.erase(key)

static func bucket_erase(groups: Dictionary, key, value) -> void:
	if groups.has(key):
		groups[key].erase(value)
		_drop_empty(groups, key)

static func bucket_pop(groups: Dictionary, key):
	if not groups.has(key):
		return null
	var last = groups[key].pop_back()
	_drop_empty(groups, key)
	return last

static func split_i64(value: int) -> PackedInt32Array:
	return PackedInt32Array([value >> 32, value])

static func join_i64(halves: PackedInt32Array) -> int:
	return (int(halves[0]) << 32) | (int(halves[1]) & 0xffffffff)
