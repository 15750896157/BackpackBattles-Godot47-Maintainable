extends Node2D

signal close_requested(cancelled: bool)

const confirmationParticles = preload("res://Interface/Lobbies/UIConfirmationParticles.tscn")

var isOpen = false
var curLobbyCode: String
var startLocalGameButton: Button

@onready var LOBBIES = RunDatabase.lobbies

@onready var lobbySearchbar = $Searchbar
@onready var statusLabel = $StatusLabel
@onready var joinButton = $JoinButton
@onready var startTimer = $StartTimer
@onready var cancelButton = $CancelButton
@onready var lobbyInfo = $LobbyInfo
@onready var speedSlider = $LobbyInfo/LobbySpeed/Speed
@onready var runDurationLabel = $LobbyInfo/LobbySpeed/RunDuration
@onready var customRulesIcon = $LobbyInfo/CustomRulesIcon
@onready var matchmakingLabel = $LobbyInfo/Matchmaking
@onready var matchmakingTooltipArea = $LobbyInfo/TooltipArea
@onready var prioritizeHostNode = $LobbyInfo/PrioritizeHost

func _ready():
	return load("res://Runtime/Behavior/Interface/Lobbies/JoinLobbyUIBehavior.gd")._ready(self)

func setConnected(connected: bool):
	return load("res://Runtime/Behavior/Interface/Lobbies/JoinLobbyUIBehavior.gd").setConnected(self, connected)

func isLobbyCodeWellFormated(code) -> bool:
	return code.length() >= 5

func onSearchbarInput(event):
	if lobbySearchbar.has_focus() and Util.isClickEvent(event):
		Util.showScreenKeyboard(lobbySearchbar)
		Game.onClickButton()

func onSearchbarTextChanged(newText):
	return load("res://Runtime/Behavior/Interface/Lobbies/JoinLobbyUIBehavior.gd").onSearchbarTextChanged(self, newText)

func onSearchbarTextEnter(_newText):
	onJoinPressed()

func onJoinPressed():
	statusLabel.setTranslationKey("STATUS_Connecting")
	LOBBIES.joinParty(curLobbyCode)
	joinButton.disabled = true
	lobbySearchbar.editable = false

func onJoinResult(res):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/JoinLobbyUIBehavior.gd").onJoinResult(self, res)

func onConnected():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/JoinLobbyUIBehavior.gd").onConnected(self)

func onStartLocalGamePressed():
	if isOpen and LOBBIES.isHost():
		Game.onClickButton()
		startLocalGameButton.hide()
		LOBBIES.startCountdown()

func reset():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/JoinLobbyUIBehavior.gd").reset(self)

func open():
	show()
	isOpen = true
	reset()

	Game.suspendRunState()
	setConnected(true)
	Util.localizeFonts(self)
	updateLocale()

func opened():
	InputBlocker.deactivate(InputBlocker.Source.Popup)

func close():
	isOpen = false
	if is_instance_valid(startLocalGameButton): startLocalGameButton.hide()

	setConnected(false)

func onKickedFromLobby(_responseCode):

	onRemovedFromLobby()

func onLobbyClosed():

	onRemovedFromLobby()

func onRemovedFromLobby():
	startTimer.stop()
	InputBlocker.restoreAllControls(InputBlocker.Source.Lobby)
	reset()

func cancel():
	close()
	LOBBIES.leaveLobby()
	Game.initPlayerFromRunstate()

	emit_signal("close_requested", true)

func startCountdown():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/JoinLobbyUIBehavior.gd").startCountdown(self)

func onCountdownEnded():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/JoinLobbyUIBehavior.gd").onCountdownEnded(self)

func onConfigChanged():
	return load("res://Runtime/Behavior/Interface/Lobbies/JoinLobbyUIBehavior.gd").onConfigChanged(self)

func updateLocale():
	lobbySearchbar.placeholder_text = Util.tra("UI_EnterCode")
