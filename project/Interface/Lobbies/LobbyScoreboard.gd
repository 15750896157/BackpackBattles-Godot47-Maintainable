extends ResizableControl

const memberLine = preload("res://Interface/Lobbies/LobbyScoreboardEntry.tscn")
@onready var memberContainer = $ScrollContainer/VBoxContainer
@onready var scrollContainer = $ScrollContainer
var memberEntries: Dictionary
var isOpen = false

@onready var LOBBIES = RunDatabase.lobbies

func open():
	if not is_inside_tree():
		LOBBIES.scoreboardNode.add_child(self)
	isOpen = true
	show()

func close():

	LOBBIES.scoreboardNode.remove_child(self)
	isOpen = false

func _ready():
	super._ready()

	clear()
	Game.connect("menu_opened", Callable(self, "onMenuOpened"))
	Game.connect("menu_close", Callable(self, "onMenuClose"))
	LOBBIES.connect("member_removed", Callable(self, "removeMember"))
	for memberId in LOBBIES.memberList:
		addMember(memberId)
	LOBBIES.connect("score_changed", Callable(self, "updateMember"))
	LOBBIES.scoreboardNode.call_deferred("remove_child", self)
	scrollContainer.get_v_scroll_bar().connect("visibility_changed", Callable(self, "onScrollbarVisibilityChanged"))
	onScrollbarVisibilityChanged()

func clear():
	for child in memberContainer.get_children():
		child.queue_free()
	memberEntries.clear()

func addMember(steamId):
	var line = memberLine.instantiate()
	memberContainer.add_child(line)
	memberEntries[steamId] = line
	line.setPlayerId(steamId)

func removeMember(steamId):
	var entry = memberEntries[steamId]
	entry.queue_free()
	memberEntries.erase(steamId)

func updateMember(memberId = null):
	return load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksL.gd").ForLobbyScoreboard.updateMember(self, memberId)

func updateRankings():
	for memberId in memberEntries:
		memberEntries[memberId].setRanking(RunDatabase.lobbies.getMemberRanking(memberId))

func onMenuOpened():
	if isOpen:
		hide()

func onMenuClose():
	if isOpen:
		show()

func onScrollbarVisibilityChanged():
	return load("res://Runtime/Callbacks/Interface/Lobbies/CallbacksL.gd").ForLobbyScoreboard.onScrollbarVisibilityChanged(self)

func canDrag():
	return super.canDrag() and not scrollContainer.scrollbarHovered
