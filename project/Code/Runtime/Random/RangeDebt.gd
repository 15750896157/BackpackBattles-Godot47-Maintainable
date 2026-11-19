extends RefCounted
## Integer range sampler with a bounded correction of accumulated drift.

var acc = 0.0

func reset():
	acc = 0.0

func randIntRange(lower: int, upper: int) -> int:
	var sample = Util.rng.randi_range(lower, upper)
	var deviation: float = sample - 0.5 * (lower + upper)
	var correction = 0
	if absf(acc) >= 1.0:
		correction = clampi(int(acc), sample - upper, sample - lower)
	acc -= correction
	acc += deviation
	return sample - correction
