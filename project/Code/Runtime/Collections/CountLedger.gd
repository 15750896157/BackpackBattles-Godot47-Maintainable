extends RefCounted
## Mutable counts. Zero is a stored value; removal erases non-positive results.

var dict: Dictionary = {}

func is_empty() -> bool:
	return dict.is_empty()

func fromCounter(other):
	dict = other.dict.duplicate()
	return self

func clear() -> void:
	dict.clear()

func add(key, amount = 1) -> void:
	dict[key] = dict.get(key, 0) + amount

func remove(key, amount: int = 1) -> void:
	var remainder = dict.get(key, 0) - amount
	if remainder > 0:
		dict[key] = remainder
	else:
		dict.erase(key)

func setCount(key, amount: int) -> void:
	dict[key] = amount

func getCount(key) -> int:
	return dict.get(key, 0)

func has(key) -> bool:
	return dict.has(key)

func _apply_keys(keys: Array, operation: Callable) -> void:
	for key in keys:
		operation.call(key)

func _apply_counts(counts: Dictionary, operation: Callable) -> void:
	for key in counts:
		operation.call(key, counts[key])

func addList(keys: Array) -> void:
	_apply_keys(keys, add)

func removeList(keys: Array) -> void:
	_apply_keys(keys, remove)

func addDict(counts: Dictionary) -> void:
	_apply_counts(counts, add)

func removeDict(counts: Dictionary) -> void:
	_apply_counts(counts, remove)

func addCounter(other) -> void:
	addDict(other.dict)

func removeCounter(other) -> void:
	removeDict(other.dict)

func countAll() -> int:
	return dict.values().reduce(func(total, value): return total + value, 0)

func isDictIn(required: Dictionary) -> bool:
	return required.keys().all(func(key): return dict.get(key, 0) >= required[key])

func isCounterIn(other) -> bool:
	return isDictIn(other.dict)

func getKeys() -> Array:
	return dict.keys()

func getValues() -> Array:
	return dict.values()

func printDict():
	print(dict)

func printItems():
	for key in dict:
		print(key.getName(), ": ", dict[key])
