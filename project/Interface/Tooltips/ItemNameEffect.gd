@tool
extends RichTextEffect

@export var water_curve: Curve
@export var water_gradient: Gradient
@export var water_cycle: float
@export var water_offset: float
@export var water_frequency: float
@export var water_speed: float = 1.0
@export var water_starttimeoffset: float = 1.0

@export var shaky_curve: Curve
@export var shaky_cycle: float
@export var shaky_speed: float = 1.0
@export var shaky_strength: float = 1.0
@export var shaky_starttimeoffset: float = 1.0

@export var ice_gradient: Gradient
@export var ice_cycle: float = 1.0
@export var ice_speed: float = 1.0

@export var spooky_gradient: Gradient
@export var spooky_cycle: float = 1.0
@export var spooky_speed: float = 1.0

@export var fire_gradient: Gradient
@export var fire_cycle: float = 1.0
@export var fire_speed: float = 1.0

@export var vampiric_gradient: Gradient
@export var vampiric_cycle: float = 1.0
@export var vampiric_speed: float = 1.0

@export var gold_gradient: Gradient
@export var gold_cycle: float = 1.0
@export var gold_speed: float = 1.0

@export var light_gradient: Gradient
@export var light_cycle: float = 1.0
@export var light_speed: float = 1.0

@export var nature_gradient: Gradient
@export var nature_cycle: float = 1.0
@export var nature_speed: float = 1.0

@export var magic_gradient: Gradient
@export var magic_cycle: float = 1.0
@export var magic_speed: float = 1.0

@export var steel_gradient: Gradient
@export var steel_cycle: float = 1.0
@export var steel_speed: float = 1.0

@export var stone_gradient: Gradient
@export var stone_cycle: float = 1.0
@export var stone_speed: float = 1.0

@export var poison_gradient: Gradient
@export var poison_curve: Curve
@export var poison_cycle: float = 1.0
@export var poison_speed: float = 1.0
@export var poison_offset: float = 1.0

@export var rainbow_gradient: Gradient
@export var rainbow_cycle: float = 1.0
@export var rainbow_color_speed: float = 1.0
@export var rainbow_frequency: float = 1.0
@export var rainbow_offset: float = 10.0
@export var rainbow_curve: Curve
@export var rainbow_wave_speed: float = 1.0

@export var lightning_curve: Curve
@export var lightning_cycle: float
@export var lightning_speed: float = 1.0
@export var lightning_strength: float = 1.0
@export var lightning_starttimeoffset: float = 1.0
@export var lightning_gradient: Gradient
@export var lightning_offset: float = 0.1

@export var stompy_curve: Curve
@export var stompy_gradient: Gradient
@export var stompy_cycle: float
@export var stompy_offset: float
@export var stompy_frequency: float
@export var stompy_speed: float = 1.0
@export var stompy_starttimeoffset: float = 1.0

@export var mercury_curve: Curve
@export var mercury_gradient: Gradient
@export var mercury_cycle: float
@export var mercury_offset: float
@export var mercury_frequency: float
@export var mercury_speed: float = 1.0
@export var mercury_starttimeoffset: float = 1.0

@export var dog_curve: Curve
@export var dog_gradient: Gradient
@export var dog_cycle: float
@export var dog_strength: float
@export var dog_speed: float = 1.0
@export var dog_starttimeoffset: float = 1.0
@export var dog_randomness: float = 1.0

@export var spring_curve: Curve
@export var spring_cycle: float
@export var spring_strength: float
@export var spring_speed: float = 1.0
@export var spring_starttimeoffset: float = 1.0
@export var spring_randomness: float = 1.0

@export var hyper_curve: Curve
@export var hyper_gradient: Gradient
@export var hyper_cycle: float
@export var hyper_strength: float
@export var hyper_speed: float = 1.0
@export var hyper_starttimeoffset: float = 1.0
@export var hyper_randomness: float = 1.0

var bbcode = "item"

func rand1(a) -> float:
	return abs(sin(a * 47.0432572429))

func rand(a: int, b: int) -> float:
	return abs(sin(a * 2349.230948234 + b * 95834.0497502587))

var _style_profiles: Dictionary = {}

func _initialize_profiles():
	# Resolve enum references lazily: tooltip resources can load this @tool effect.
	var styles = ItemToolTip.TextEffect
	_style_profiles = {
		styles.Water: ["wave", "water"],
		styles.Stompy: ["wave", "stompy"],
		styles.Mercury: ["wave", "mercury"],
		styles.Ice: ["color", "ice", 0.5, 1.0, 0.0, false],
		styles.Fire: ["color", "fire", 0.5, 1.0, 0.0, false],
		styles.Vampiric: ["color", "vampiric", 0.0, -0.2, 0.0, false],
		styles.Spooky: ["color", "spooky", 0.1, 1.0, 0.0, false],
		styles.Gold: ["color", "gold", 0.0, -0.2, 0.0, false],
		styles.Light: ["color", "light", 0.0, -0.2, 0.0, false],
		styles.Nature: ["color", "nature", 0.0, -0.1, 0.0, false],
		styles.Magic: ["color", "magic", 0.8, 1.0, 0.0, false],
		styles.Steel: ["color", "steel", 0.0, -0.2, 0.0, false],
		styles.Stone: ["color", "stone", 1.0, 1.0, 500.0, false],
		styles.Poison: ["color", "poison", 1.0, 1.0, 500.0, true],
		styles.Shaky: ["shake", "shaky", 0.2, 200.0, false],
		styles.Dog: ["shake", "dog", null, 0.0, false],
		styles.Dog2: ["shake", "dog", null, 0.0, true],
		styles.Spring: ["shake", "spring", null, 0.0, false],
		styles.Hyper: ["shake", "hyper", null, 0.0, true],
		styles.Rainbow: ["rainbow"],
		styles.Lightning: ["lightning"],
	}
	# Property names are prepared once; values stay live for editor adjustments.
	for profile in _style_profiles.values():
		if profile.size() < 2: continue
		var prefix: String = profile[1]
		var properties: Dictionary = {}
		for suffix in ["gradient", "speed", "cycle", "curve", "offset", "frequency", "starttimeoffset", "strength", "randomness"]:
			properties[suffix] = StringName(prefix + "_" + suffix)
		profile[1] = properties

func _process_custom_fx(char_fx: CharFXTransform):
	if _style_profiles.is_empty(): _initialize_profiles()
	var profile: Array = _style_profiles.get(int(char_fx.env.get("s", 0)), [])
	if profile.is_empty(): return true
	match profile[0]:
		"color": _apply_color_profile(char_fx, profile)
		"wave":
			var keys: Dictionary = profile[1]
			wave(char_fx, get(keys.frequency), get(keys.starttimeoffset), get(keys.speed),
				get(keys.cycle), get(keys.gradient), get(keys.curve), get(keys.offset))
		"shake": _apply_shake_profile(char_fx, profile)
		"rainbow": _apply_rainbow_frame(char_fx)
		"lightning": _apply_lightning_frame(char_fx)
	return true

func _apply_color_profile(char_fx, profile: Array):
	var keys: Dictionary = profile[1]
	var phase = setColorFromGradient(char_fx, get(keys.gradient), get(keys.speed),
		get(keys.cycle), profile[2], profile[3], profile[4])
	if profile[5]: char_fx.offset.y = -get(keys.offset) * get(keys.curve).sample(phase)

func _apply_shake_profile(char_fx, profile: Array):
	var keys: Dictionary = profile[1]
	var randomness = get(keys.randomness) if profile[2] == null else profile[2]
	var phase = shake(char_fx, get(keys.speed), get(keys.starttimeoffset), get(keys.cycle),
		get(keys.curve), get(keys.strength), randomness, profile[3])
	if profile[4]: char_fx.color = get(keys.gradient).sample(phase)

func _apply_rainbow_frame(char_fx):
	setColorFromGradient(char_fx, rainbow_gradient, rainbow_color_speed, rainbow_cycle, 0.0, -0.2, 20.0)
	var phase = 20 + char_fx.range.x * -rainbow_frequency
	phase += char_fx.elapsed_time
	phase *= rainbow_wave_speed
	char_fx.offset.y = -rainbow_offset * rainbow_curve.sample(fmod(phase, rainbow_cycle))

func _apply_lightning_frame(char_fx):
	var phase = char_fx.range.x * -lightning_offset
	phase += char_fx.elapsed_time * lightning_speed - lightning_starttimeoffset
	var iteration = int(phase / lightning_cycle)
	var rng = rand(char_fx.range.x, iteration)
	var angle = rng * 200 * PI
	var time = fmod(phase - rng * 0.2, lightning_cycle)
	var strength = 0.5 + lightning_strength * rand1(rng)
	char_fx.offset += Vector2(lightning_curve.sample(time) * strength, 0).rotated(angle)
	char_fx.color = lightning_gradient.sample(time)

func setColorFromGradient(char_fx, gradient, speed, cycle,
	rngFactor = 0.0, positionFactor = 1.0, preprocess = 0.0):

	var phase = preprocess + char_fx.range.x * positionFactor
	phase += char_fx.elapsed_time
	phase *= (1 + rand1(char_fx.range.x) * rngFactor) * speed
	var sampleX = fmod(phase, cycle)
	char_fx.color = gradient.sample(sampleX)
	return sampleX

func wave(char_fx, frequency, startTimeOffset, speed,
		cycle, gradient, curve, offset):

	var phase = char_fx.range.x * - frequency
	phase += char_fx.elapsed_time - startTimeOffset
	phase *= speed
	var sampleX = fmod(phase, cycle)
	char_fx.color = gradient.sample(sampleX)
	char_fx.offset.y = - offset * curve.sample(sampleX)

func shake(char_fx, speed, startTimeOffset, cycle, curve, strength,
			randomness, angleRange):

	var phase = char_fx.elapsed_time * speed - startTimeOffset
	var iteration = int(phase / cycle)
	var rng = rand(char_fx.range.x, iteration)
	var angle = rng * angleRange * PI
	var tInIteration = fmod(phase - rng * randomness, cycle)
	var totalStrength = 0.5 * rand1(rng) + strength
	char_fx.offset += Vector2(0, - curve.sample(
		tInIteration) * totalStrength).rotated(angle)
	return tInIteration
