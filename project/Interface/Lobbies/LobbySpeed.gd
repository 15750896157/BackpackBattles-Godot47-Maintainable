extends Node2D

@onready var runDurationLabel = $RunDuration
@onready var LOBBIES = RunDatabase.lobbies

func _ready():
	add_to_group("Localized")
	Util.localizeFonts(runDurationLabel)
	LOBBIES.connect("config_changed", Callable(self, "onSpeedChanged"))
	onSpeedChanged()

func updateLocale():
	onSpeedChanged()

func onSpeedChanged():
	return load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksL.gd").ForLobbySpeed.onSpeedChanged(self)

