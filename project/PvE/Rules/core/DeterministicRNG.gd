class_name DeterministicRNG
extends RefCounted

# A separate, explicit 32-bit stream avoids JSON integer precision loss.
var state: int = 1

func _init(seed_value: int = 1):
	state = seed_value & 0xffffffff

func next_int() -> int:
	state = (1664525 * state + 1013904223) & 0xffffffff
	return state

func unit() -> float:
	return float(next_int()) / 4294967296.0

func choose(values: Array):
	if values.is_empty(): return null
	return values[next_int() % values.size()]

func weighted(values: Array, weights: Array):
	if values.is_empty(): return null
	var total: float = 0.0
	for w in weights: total += maxf(0.0, float(w))
	if total <= 0.0: return values[0]
	var roll: float = unit() * total
	for i in values.size():
		roll -= maxf(0.0, float(weights[i]))
		if roll < 0.0: return values[i]
	return values.back()
