extends Node2D

const fatigueStartSound = preload("res://Assets/Sound/Fatigue.wav")
const FATIGUE_TIME = 17
const MAX_SPEED = 3.0

@onready var fatigueStartTimer = $FatigueStartTimer
@onready var timeLabel = $Time
@onready var speedLabel = $Speed
@onready var speedSlider = $SpeedSlider
@onready var pauseButton = $PauseButton
@onready var fastButton = $FastButton
@onready var animation = $AnimationPlayer
@onready var fatigueTickTimer = $FatigueTickTimer
@onready var fatigueAnimation = get_parent().get_node("Fatigue/AnimationPlayer")
@onready var fatigueLabel = get_parent().get_node("Fatigue/Counter")

var fatigueCounter: int
var speedBeforePause = 1.0
var combatTime: float
var timeAdvance: float
var startSpeed: float

func _ready() -> void :
	set_physics_process(false)
	Game.connect("combat_scene_entered", Callable(self, "onCombatSceneEntered"))
	set_process_unhandled_input(false)

func initialize():
	return load("res://Runtime/Behavior/Interface/CombatTimer/CombatTimerBehavior.gd").initialize(self)

func initButtons():
	pauseButton.show()
	fastButton.show()
	speedSlider.modulate = Color.WHITE

func forceSpeed(speed):
	speedSlider.editable = true
	speedSlider.max_value = MAX_SPEED
	speedSlider.set_value(speed)
	speedSlider.editable = false

func forceMaxSpeed():
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").forceMaxSpeed(self)

func isMaxSpeedForced():
	return not pauseButton.visible

func getSpeed() -> float:
	return speedSlider.value

func getEffectiveTime() -> float:
	return Game.COMBAT_DELAY + combatTime + timeAdvance

func onCombatSceneEntered():
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").onCombatSceneEntered(self)

func getName():
	return "Fatigue"

func combatEnd():
	return load("res://Runtime/Behavior/Interface/CombatTimer/CombatTimerBehavior.gd").combatEnd(self)

func start():
	fatigueStartTimer.stop()
	fatigueTickTimer.stop()
	set_physics_process(false)
	return

func _physics_process(delta: float) -> void :
	return

func _unhandled_input(event):
	return load("res://Runtime/Behavior/Interface/CombatTimer/CombatTimerBehavior.gd")._unhandled_input(self, event)

func updateTimer():
	timeLabel.text = "%1.1f" % combatTime

func getTimeStamp():
	return combatTime

func startFatigue():
	return

func dealFatigueDamage():
	return

func hasFatigueStarted() -> bool:
	return fatigueCounter > 0

func advanceTime(time):
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").advanceTime(self, time)

func onSpeedChanged(value: float) -> void :
	load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").onSpeedChanged(self, value)

func onPauseButtonPressed():
	if not pve_combat_active(): return
	if Expedition.flow.combat_paused: unpause()
	else: pause()
	Game.onClickButton()
	return

func pause():
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").pause(self)

func unpause():
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").unpause(self)

func onFastButtonPressed():
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").onFastButtonPressed(self)

func speedUp(amount):
	if not pve_combat_active(): return
	speedSlider.set_value(2.0 if Expedition.flow.combat_speed < 2.0 else 4.0)
	return

func speedDown(amount):
	if not pve_combat_active(): return
	speedSlider.set_value(2.0 if Expedition.flow.combat_speed > 2.0 else 1.0)
	return

func pve_combat_active() -> bool:
	return load("res://Runtime/Behavior/Features/Interface/CombatTimer/CombatTimerBehavior.gd").pve_combat_active(self)

func setTime(time):
	updateTimer()
