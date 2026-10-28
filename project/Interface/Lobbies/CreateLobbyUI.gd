extends Node2D

signal close_requested(cancelled: bool)

const confirmationParticles = preload("res://Interface/Lobbies/UIConfirmationParticles.tscn")
const buttonGroup = preload("res://Interface/Lobbies/MatchmakingButtonGroup.tres")
const successSound = preload("res://Assets/Sound/Chime2.mp3")

var isOpen = false

@onready var LOBBIES = RunDatabase.lobbies
@onready var createLobbyButton = $CreateLobbyButton
@onready var lobbyCodeLabel = $LobbyCode/LobbyCode
@onready var statusLabel = $StatusLabel
@onready var startGameButton = $StartGameButton
@onready var cancelButton = $CancelButton
@onready var cancelButtonLabel = $CancelLabel
@onready var lobbyCodeNode = $LobbyCode
@onready var copyButton = $LobbyCode/CopyButton
@onready var startTimer = $StartTimer
@onready var speedSlider = $Settings/LobbySpeed/Speed
@onready var runDurationLabel = $Settings/LobbySpeed/RunDuration
@onready var memberLimitApplyTimer = $Settings/ApplyTimer
@onready var memberLimitSpinbox = $Settings/MemberLimit

@onready var customRulesTooltip = $CustomRulesTooltip
@onready var customRulesInput = $CustomRulesTooltip/VBoxContainer
@onready var customRulesTimer = $Settings/CustomRulesTimer
@onready var customRulesIcon = $Settings/CustomIcon

@onready var matchmakingTooltip = $MatchmakingTooltip
@onready var matchmakingModes = $MatchmakingTooltip/Modes
var matchmakingButtons: Array

@onready var prioritizeHostButton = $MatchmakingTooltip/PrioritizeHost/Button

func _ready():
	return load("res://Runtime/Behavior/Interface/Lobbies/CreateLobbyUIBehavior.gd")._ready(self)

func setConnected(connected: bool):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/CreateLobbyUIBehavior.gd").setConnected(self, connected)

func setStatus(status):
	statusLabel.setTranslationKey(status)

func open():
	return load("res://Runtime/Behavior/Interface/Lobbies/CreateLobbyUIBehavior.gd").open(self)

func onCreateLobbyPressed():

	createLobbyButton.hide()
	statusLabel.show()
	setStatus("STATUS_CreatingLobby")
	LOBBIES.createParty()

func onLobbyCreated(lobbyId: String):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/CreateLobbyUIBehavior.gd").onLobbyCreated(self, lobbyId)

func onSpeedChanged(value: float):
	LOBBIES.setSpeed_Host(int(value))

func onMemberLimitChanged(value: float):
	memberLimitApplyTimer.start(0.3)

func updateMemberLimit():
	LOBBIES.setLobbySize_Host(int(memberLimitSpinbox.value))

func onCopyButtonPressed():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/CreateLobbyUIBehavior.gd").onCopyButtonPressed(self)

func onStartGamePressed():
	return load("res://Runtime/Behavior/Interface/Lobbies/CreateLobbyUIBehavior.gd").onStartGamePressed(self)

func onCountdownEnded():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/CreateLobbyUIBehavior.gd").onCountdownEnded(self)

func close():
	isOpen = false
	setConnected(false)

func onCancelPressed():
	close()

	LOBBIES.leaveLobby()
	Game.initPlayerFromRunstate()

	emit_signal("close_requested", true)

func onCustomRulesPressed():
	if customRulesTooltip.visible:
		hideCustomRules()
	else:
		showCustomRules()

func showCustomRules():
	customRulesTooltip.show()
	customRulesInput.onOpen()

func hideCustomRules():
	customRulesTooltip.hide()

func onCustomRulesChanged():
	customRulesTimer.start(0.5)
	if CustomRules.areCustomRulesChanged():
		customRulesIcon.texture = CustomRules.activeIcon
	else:
		customRulesIcon.texture = CustomRules.defaultIcon

func applyCustomRules():
	if CustomRules.areCustomRulesChanged():
		LOBBIES.setCustomRules_Host(CustomRules.serialize())
	else:
		LOBBIES.setCustomRules_Host("")

func onMatchmakingPressed():
	if matchmakingTooltip.visible:
		matchmakingTooltip.hide()
	else:
		matchmakingTooltip.show()

func onMatchmakingSelected(mode: int):
	LOBBIES.setMatchMaking_Host(mode, LOBBIES.prioritizeHost)

func onPrioritizeHostToggled(pressed):
	LOBBIES.setMatchMaking_Host(LOBBIES.matchMaking, pressed)
