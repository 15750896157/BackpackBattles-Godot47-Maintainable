extends "res://Interface/Combat/BlockHud.gd"

@export var cooldown = 2.0
@export var offset = 0.0
@export var activationAnimation: PackedScene

var particles

func _ready():
	super._ready()
	Game.connect("combat_start", Callable(self, "onCombatStart"))
	particles = activationAnimation.instantiate()
	sprite.add_child(particles)
	sprite.material = sprite.material.duplicate()
	sprite.material.set_shader_parameter("progress", 1.0)
	set_process(false)

func onCombatStart():
	set_process(true)

func onLeaveCombat():
	super.onLeaveCombat()
	set_process(false)

func _process(delta):
	var progress = fmod(Game.getCombatOrReplayTime() - offset, cooldown) / cooldown
	sprite.material.set_shader_parameter("progress", 1.0 - progress)

func activate():
	particles.activate()
