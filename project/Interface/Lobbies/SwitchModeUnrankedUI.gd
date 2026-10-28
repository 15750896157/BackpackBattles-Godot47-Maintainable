extends "res://Interface/Lobbies/CustomUnrankedUI.gd"

const localeMargins = {
	"en": 1522,
	"pt": 1576,
	"es": 1576,
}

func startGame():
	CustomRules.setSwitchMode(CustomRules.SwitchModeState.Unranked)
	super.startGame()

func _ready():
	super._ready()
	$Hint.formatParams = {"gold": Util.getIcon("gold")}
	add_to_group("Localized")

func open():
	super.open()
	updateLocale()

func updateLocale():
	return load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksS.gd").ForSwitchModeUnrankedUI.updateLocale(self)

