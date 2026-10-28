extends Item

@onready var manaNeeded = int(getP("manat"))
@onready var numDebuffs = int(getP("debuffs"))
@onready var bonusPoison = int(getP("poison"))
@onready var bonusBlind = int(getP("blind"))
@onready var bonusCold = int(getP("cold"))

var typesDict

func canAffect(item):
	return (item.hasType(Type.Nature) or
			item.hasType(Type.Dark) or
			item.hasType(Type.Ice))

func onPrepare():
	typesDict = countTypes(getAffectedItems())

func getDescription(wrapInColor = true):
	var descr = super.getDescription(wrapInColor)
	if not placed:
		descr = descr.replace("$n_nature", "")
		descr = descr.replace("$n_dark", "")
		descr = descr.replace("$n_ice", "")
		return descr

	typesDict = countTypes(getAffectedItems())

	descr = insertCounter(descr, "n_nature", typesDict[Type.Nature])
	descr = insertCounter(descr, "n_dark", typesDict[Type.Dark])
	descr = insertCounter(descr, "n_ice", typesDict[Type.Ice])

	return descr

func doCooldownEffect():
	return load("res://Runtime/Callbacks/Items/Exclusive/CallbacksB.gd").ForBewitchment.doCooldownEffect(self)

