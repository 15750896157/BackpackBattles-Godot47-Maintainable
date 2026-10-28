extends ScrollContainer

const entryScene = preload("res://Interface/Lobbies/LobbyMemberEntry.tscn")

@onready var vboxContainer = $VBoxContainer
var memberEntries: Dictionary

func _ready():
	load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksL.gd").ForLobbyMemberList._ready(self)

func addMember(steamId):
	var entry = entryScene.instantiate()
	vboxContainer.add_child(entry)
	entry.setSteamId(steamId)
	memberEntries[steamId] = entry

func removeMember(steamId):
	var entry = memberEntries[steamId]
	entry.queue_free()
	memberEntries.erase(entry)

func clear():
	for entry in vboxContainer.get_children():
		entry.queue_free()

	memberEntries.clear()

func onScrollbarVisibilityChanged():
	if get_v_scroll_bar().visible:
		size.x = 400
	else:
		size.x = 335
