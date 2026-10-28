extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Healthbar.gd")

static func _ready(subject: Receiver) -> void :
	subject.character.connect("health_changed_ui", Callable(subject, "onHealthChanged"))
	subject.healthbarMat.set_shader_parameter("lastDamagePercentage", 1)
	subject.healthbarMat.set_shader_parameter("healthPercentage", 1)
	subject.call_deferred("ready_deferred")

static func updateBar(subject: Receiver):
	subject.updateQueued = false

	var maxHealth = subject.character.getMaxHealth()
	var relHealth = subject.character.getRelativeHealth()
	subject.healthbarMat.set_shader_parameter("lastDamagePercentage", relHealth)
	subject.tween.stop_all()
	subject.tween.remove_all()
	subject.tween.interpolate_property(subject.healthbarMat, "shader_parameter/healthPercentage", null, relHealth, 0.5)

	subject.tween.start()

	if relHealth < subject.lastRelHealth:
		var amount = round((subject.lastRelHealth - relHealth) * 130)
		if amount > 0:
			var particles = ObjectPool.particleOneShot(subject.healthLostParticles, subject.bar)
			particles.amount = amount
			var leftBorder = relHealth * subject.barWidth
			var rightBorder = subject.lastRelHealth * subject.barWidth
			var xPos = 0.5 * (rightBorder + leftBorder)
			particles.position = Vector2(xPos, 22)
			var boxWidth = 0.5 * (rightBorder - leftBorder)
			particles.process_material.emission_box_extents.x = boxWidth

	subject.updateNumber()

	subject.lastRelHealth = relHealth
