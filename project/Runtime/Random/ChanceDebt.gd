extends RefCounted
## Feedback samplers share the caller's RNG; boundary probabilities draw nothing.

var expectedWins = Util.rng.randf_range(0.2, -0.2)
var wins = 0
var balancedness = 3.0
var lastResult = false
var extraLuck = 0.0
var lastTarget = 0.0
var accChance = 0.0
const luckBalance = 0.2

func _init(start_bias = 0.0):
	expectedWins += start_bias

func setBias(bias):
	expectedWins += bias

func rollPercent(percent) -> bool:
	return roll(percent / 100.0)

func roll(target) -> bool:
	if target <= 0.0 or target >= 1.0:
		return target >= 1.0
	var probability = target
	var debt = expectedWins - wins
	if absf(debt) > 0.3:
		var adjustment = balancedness * minf(1.0, absf(debt))
		probability = probability * adjustment if debt > 0.0 else probability / adjustment
	expectedWins += target
	if lastResult and target < 0.4:
		probability *= 0.5
	elif not lastResult and target > 0.6:
		probability *= 2.0
	lastResult = Util.flip(probability)
	wins += int(lastResult)
	return lastResult

func roll2(target) -> bool:
	if target <= 0.0 or target >= 1.0:
		return target >= 1.0
	var won = Util.flip(target + extraLuck * 0.3)
	extraLuck += target - float(won)
	return won

func roll1(target) -> bool:
	if target <= 0.0 or target >= 1.0:
		return target >= 1.0
	accChance += target - lastTarget
	extraLuck += clampf(accChance, 0.0, 1.0) - target
	lastTarget = target
	var won = Util.flip(accChance)
	accChance = target - extraLuck if won else accChance + luckBalance
	return won

func reset():
	var defaults = {"expectedWins": 0.0, "wins": 0, "lastResult": false,
		"extraLuck": 0.0, "accChance": 0.0, "lastTarget": 0.0}
	for property in defaults:
		set(property, defaults[property])
