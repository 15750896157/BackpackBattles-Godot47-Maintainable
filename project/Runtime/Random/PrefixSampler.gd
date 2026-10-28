extends RefCounted
## Prefix sampling retains one RNG draw and the first-equal boundary rule.

var weightSums: Array = []
var acc

func prepare(weights: Array) -> void:
	weightSums.assign(weights)
	acc = 0
	for index in weightSums.size():
		acc += weightSums[index]
		weightSums[index] = acc

func roll():
	var sample = Util.rng.randf_range(0.0, acc)
	var lower = 0
	var upper = weightSums.size()
	while lower < upper:
		var middle = (lower + upper) / 2
		if weightSums[middle] < sample:
			lower = middle + 1
		else:
			upper = middle
	if lower < weightSums.size():
		return lower
	Util.eassert()
	return weightSums.size() - 1

func rollOnce(weights: Array):
	prepare(weights)
	return roll()
