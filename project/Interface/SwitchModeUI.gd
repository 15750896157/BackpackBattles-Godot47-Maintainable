extends Node2D

signal close_requested(cancelled: bool)

@onready var leagueProgressUI = $LeagueProgress

func _ready():
	$Hint.formatParams = {"gold": Util.getIcon("gold")}
	add_to_group("Localized")
	updateLocale()

func updateLocale():
	pass

func open():
	show()
	leagueProgressUI.updateUI(null)

func close():
	pass

func onCancelPressed():
	close()
	emit_signal("close_requested", true)

func startGame():
	return load("res://Runtime/Callbacks/Interface/CallbacksS.gd").ForSwitchModeUI.startGame(self)

