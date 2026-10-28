extends Node2D
class_name CharacterStatIcon

const suffixes = {
	Character.Stat.HealEfficiency: "%",
	Character.Stat.DamageResistance: "%",
	Character.Stat.CritResistance: "%",
	Character.Stat.StunResistance: "%",
	Character.Stat.MeleeDmgFactor: "%",
	Character.Stat.RangedDmgFactor: "%",
	Character.Stat.EffectDmgFactor: "%",
	Character.Stat.Unhealing: "%",
	Character.Stat.StaminaRegen: "%",
	Character.Stat.MaxHealthGain: "%"
}

const removeMinus = {
	Character.Stat.HealEfficiency: true,
	Character.Stat.DamageResistance: true,
	Character.Stat.StaminaRegen: true,
	Character.Stat.MaxHealthGain: true
}

@onready var label = $Label
@onready var icon = $TextureRect

var poolingHandle
var stat: int
var tween = null
var active = false
var default = null
var suffix = ""
var positiveTexture
var negativeTexture
var positiveKeyword: String
var negativeKeyword: String

func preset():
	pass

func setStat(_stat: int):
	return load("res://Runtime/Behavior/Interface/Combat/CharacterStatIconBehavior.gd").setStat(self, _stat)

func setStatValue(value):
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatIconBehavior.gd").setStatValue(self, value)

func updateLabel(value):
	return load("res://Runtime/Behavior/Interface/Combat/CharacterStatIconBehavior.gd").updateLabel(self, value)

func appear():
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatIconBehavior.gd").appear(self)

func disappear():
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatIconBehavior.gd").disappear(self)

func disappeared():
	hide()
	icon.hideTooltip()

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Interface/Combat/CharacterStatIconBehavior.gd")._physics_process(self, delta)

