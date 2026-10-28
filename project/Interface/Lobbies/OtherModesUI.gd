extends Node2D

signal ui_closed
signal cancel

var isOpen = false
var activeUI = null
var warpPointNodes: Array

@onready var animation = $AnimationPlayer
@onready var joinLobbyUI = $JoinLobbyUI
@onready var hostLobbyUI = $CreateLobbyUI
@onready var customUnrankedUI = $CustomUnrankedUI
@onready var switchModeRankedUI = $SwitchModeRankedUI
@onready var switchModeUnrankedUI = $SwitchModeUnrankedUI
@onready var buttons = $Buttons
@onready var customUnrankedButton = $Buttons/CustomUnranked/CustomUnrankedButton
@onready var switchModeRankedButton = $Buttons/SwitchModeRanked/Button
@onready var switchModeUnrankedButton = $Buttons/SwitchModeUnranked/Button
@onready var switchModeRankedLeague = $Buttons/SwitchModeRanked/LeagueProgress

@onready var UIs = [joinLobbyUI, hostLobbyUI, customUnrankedUI,
	switchModeRankedUI, switchModeUnrankedUI]

func _ready():
	load("res://Runtime/Behavior/Interface/Lobbies/OtherModesUIBehavior.gd")._ready(self)

func ready_deferred():
	warpPointNodes = Util.getInteractableNodes(buttons)
	for ui in UIs:
		Util.walkInteractableNodes(ui, warpPointNodes)

func open():
	return load("res://Runtime/Behavior/Interface/Lobbies/OtherModesUIBehavior.gd").open(self)

func updateLocale():
	switchModeRankedLeague.updateUI(null)

func opened():
	InputBlocker.deactivate(InputBlocker.Source.Popup)

func close(cancel: bool = false):
	return load("res://Runtime/Behavior/Interface/Lobbies/OtherModesUIBehavior.gd").close(self, cancel)

func closed():
	InputBlocker.deactivate(InputBlocker.Source.Popup)

	showButtons()
	isOpen = false
	get_parent().remove_child(self)

func showButtons():
	if activeUI != null:
		activeUI.close()
		activeUI = null
	buttons.show()

func hideButtons():
	if activeUI != null:
		activeUI.close()
	buttons.hide()

func onJoinLobbyPressed():
	hideButtons()
	activeUI = joinLobbyUI
	joinLobbyUI.open()

func onHostLobbyPressed():
	hideButtons()
	activeUI = hostLobbyUI
	hostLobbyUI.open()

func onCustomUnrankedPressed():
	hideButtons()
	activeUI = customUnrankedUI
	customUnrankedUI.open()

func onCancelPressed():
	close(true)

func onSwitchModeRankedPressed():
	hideButtons()
	activeUI = switchModeRankedUI
	switchModeRankedUI.open()

func onSwitchModeUnrankedPressed():
	hideButtons()
	activeUI = switchModeUnrankedUI
	switchModeUnrankedUI.open()

func onCursorWarp():
	for node in warpPointNodes:
		if node.is_visible_in_tree() and Util.isControlEnabled(node):
			Game.addControlOfInterest(node)
