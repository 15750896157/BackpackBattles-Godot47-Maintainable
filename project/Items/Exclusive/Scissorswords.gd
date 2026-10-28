extends "res://Items/Lightsaber.gd"

var rapierParticles = load("res://Items/Particles/RapierActivationParticles.tscn")

@onready var luckNeeded = int(getP("luckt"))
@onready var bonusDam = getP("dam")
@onready var luck = int(getP("luck"))
@onready var regen = int(getP("regen"))

func inflict(duration, event):
	super.inflict(duration, event)
	giveStacksTemporary(character(), Game.EventType.Blind,
		blind, duration, event)

func onDealtDamage(damageRes: DamageResult):
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksS.gd").ForScissorswords.onDealtDamage(self, damageRes)

