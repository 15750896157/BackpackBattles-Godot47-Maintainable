extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageNumbers/DamageNumber.gd")

static func _ready(subject: Receiver):
	subject.linear_velocity = Vector2.ZERO
	subject.gravity_scale = 0
	subject.text.modulate = Color.WHITE
	subject.text.scale = Vector2(1, 1)

	subject.font.set("outline_color", Color.BLACK)

static func spawnNumber(subject: Receiver, numberType, amount: int):
	subject.rotation = 0
	if numberType == Game.EventType.Health:
		subject.linear_velocity = Vector2(0, - 200)
		subject.animation.play("Heal")
	else:
		subject.rotation = subject.linear_velocity.x * 0.001

		if numberType == Game.EventType.CriticalDamage:
			subject.animation.play("Critical")
			subject.gravity_scale = 9.5
		else:
			subject.gravity_scale = 12
			subject.animation.play("Normal")

	var size = int(subject.SIZE_CURVE.sample(float(amount) / 100))
	subject.text.set("theme_override_fonts/normal_font", Util.damageNumberFonts[size])

	subject.text.text = Game.damageNumberFormats[numberType].format(
		{"amount": amount})
	subject.text.set("theme_override_colors/default_color", Game.damageNumberColors[numberType])

	subject.text.pivot_offset = subject.text.size * 0.5
