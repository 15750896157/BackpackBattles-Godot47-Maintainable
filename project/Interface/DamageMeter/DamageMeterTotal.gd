extends Control

var poolingHandle
var absDamageLabel
var totalLabel
var player

func preset():
	absDamageLabel = $AbsoluteDamage
	totalLabel = $Name
	Util.localizeFonts(absDamageLabel)

func init(absValue, dps: float):
	return load("res://Runtime/Callbacks/Interface/DamageMeter/CallbacksD.gd").ForDamageMeterTotal.init(self, absValue, dps)

