extends ResizableControl

const activationButtonKeys = [
	"CombatLog_HideActivations",
	"CombatLog_MinimizeActivations",
	"CombatLog_ShowActivations"
	]

var isOpen: bool = false
var buttonsReset: bool = false

@onready var searchBar = $Searchbar
@onready var openButton = $OpenButton
@onready var activationsButton = $Activations
@onready var playButton = $PlayButton
@onready var playFromStartButton = $PlayFromStartButton
@onready var playBackwardsButton = $PlayBackButton
@onready var playFromEndButton = $PlayFromEndButton

@onready var filterButtons = [
	searchBar, activationsButton,
	playButton, playFromStartButton, playBackwardsButton, playFromEndButton
]

@onready var replayButtons = [
	playButton, playFromStartButton, playBackwardsButton, playFromEndButton
]

@onready var MARGIN_TOP_OPEN = offset_top
@onready var MARGIN_RIGHT_OPEN = offset_right

func _ready() -> void :
	super._ready()
	close()
	Game.connect("returned_to_title", Callable(self, "reset"))
	Game.connect("shop_opened", Callable(self, "reset"))
	Game.connect("combat_end", Callable(self, "onCombatEnd"))
	Game.combatLog.connect("replay_finished", Callable(self, "onReplayFinished"))
	Util.localizeFonts(activationsButton)
	add_to_group("Localized")
	updateActivationsButton()
	setReplayButtonsDisabled(true)

func open():
	return load("res://Runtime/Behavior/Features/Interface/CombatLog/CombatLogFilterPanelBehavior.gd").open(self)

func close():
	return load("res://Runtime/Behavior/Features/Interface/CombatLog/CombatLogFilterPanelBehavior.gd").close(self)

func setReplayButtonsDisabled(disabled):
	for button in replayButtons:
		button.disabled = disabled

func _on_OpenButton_pressed() -> void :
	if isOpen:
		close()
	else:
		open()

func reset():
	if searchBar.text != "":
		searchBar.clear()
	setReplayButtonsDisabled(true)

func updateLocale():
	updateActivationsButton()

func updateActivationsButton():
	activationsButton.translationKey = activationButtonKeys[Game.combatLog.activationsState]
	activationsButton.updateLocale()

func onActivationsButtonPressed(_pressed):
	var newState = (Game.combatLog.activationsState + 1) % 3
	Game.combatLog.setActivationState(newState)
	updateActivationsButton()

func onPlayButtonToggled(pressed):
	if not buttonsReset:
		resetReplayButtons(playButton)
		if pressed:
			Game.combatLog.replayCombat(false)
		else:
			Game.combatLog.stopReplay()

func onPlayFromStartButtonToggled(pressed):
	if not buttonsReset:
		resetReplayButtons(playFromStartButton)
		if pressed:
			Game.combatLog.replayCombat(true)
		else:
			Game.combatLog.stopReplay()

func onPlayBackwardsButtonToggled(pressed):
	return load("res://Runtime/Behavior/Features/Interface/CombatLog/CombatLogFilterPanelBehavior.gd").onPlayBackwardsButtonToggled(self, pressed)

func onPlayFromEndButtonToggled(pressed):
	return load("res://Runtime/Behavior/Features/Interface/CombatLog/CombatLogFilterPanelBehavior.gd").onPlayFromEndButtonToggled(self, pressed)

func resetReplayButtons(except):
	buttonsReset = true
	for button in replayButtons:
		if button != except:
			button.button_pressed = false
	buttonsReset = false

func onReplayFinished():
	resetReplayButtons(null)

func onCombatEnd(_roundResult):
	setReplayButtonsDisabled(false)
