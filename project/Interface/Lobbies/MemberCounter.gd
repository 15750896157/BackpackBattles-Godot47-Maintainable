extends Label

func _ready():
	load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksM.gd").ForMemberCounter._ready(self)

func updateMemberCounter(_steamId = null):
	text = str(RunDatabase.lobbies.getNumMembers())
	text += "/"
	text += str(RunDatabase.lobbies.getLobbySize())
