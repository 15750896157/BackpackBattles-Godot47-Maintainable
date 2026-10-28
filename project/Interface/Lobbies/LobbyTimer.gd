extends Node2D

const normalFont = preload("res://Interface/Lobbies/LobbyTimerFont_normal.tres")
const hurryFont = preload("res://Interface/Lobbies/LobbyTimerFont_hurry.tres")
const countdownSound = preload("res://Assets/Sound/Countdown1.ogg")
const forceSpeedAni = preload("res://Interface/Lobbies/ForceSpeedAnimation.tscn")

const FRAMETIME: = 1.0 / 60.0
const FORCE_LOSE_TIME: = 10.0
const FORCE_TRANSITION_TIME: = 8.0
const FORCE_SPEED_TIME: = 45.0
const BASETIME = 1734611782
const PROGRESS_MODULATE_END = Color(2, 1.6, 0.8)

@onready var LOBBIES = RunDatabase.lobbies

@onready var minutesLabel_shop = $Minutes
@onready var secondsLabel_shop = $Seconds
@onready var colonLabel = $Label
@onready var waitingLabel = $Waiting
@onready var readyButton = $ReadyButton
@onready var checkMark = $Checkmark
@onready var readyCounter = $ReadyCounter
@onready var particles = $GPUParticles2D

@onready var combatNode = $Combat
@onready var minutesLabel_combat = $Combat/Minutes
@onready var secondsLabel_combat = $Combat/Seconds
@onready var colonLabel_combat = $Combat/Label

@onready var animation = $Combat/AnimationPlayer
@onready var shockwaveAni = $Shockwave/AnimationPlayer
@onready var progressSprite = $Progress

var remainingRoundTime: float
var preciseTime: float = 0
var serverTime: int
var nextFightTime: float
var timerActive = false
var curFont = normalFont
var shockwaveStarted = false
var displayTime = - 1000
var progressTween

func _ready():
	return load("res://Runtime/Behavior/Interface/Lobbies/LobbyTimerBehavior.gd")._ready(self)

func initTimer():
	if preciseTime == 0:
		preciseTime = Steam.getServerRealTime()

func showCombatTimer():
	animation.play("ShowTimer")

func hideCombatTimer():
	animation.play("HideTimer")
	showWaitLabel(false)

func updateTimer(timestamp: float):

	nextFightTime = timestamp + BASETIME

	var timeDif = nextFightTime - preciseTime
	setTimer(timeDif)
	print("update timer with diff ", timeDif)

func forwardTo(_remainingRoundTime: float):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd").forwardTo(self, _remainingRoundTime)

func setTimer(_remainingRoundTime: float):

	remainingRoundTime = _remainingRoundTime
	if remainingRoundTime < 0:

		showWaitLabel(true)

	timerActive = true
	updateTime()

func updateTime():
	return load("res://Runtime/Behavior/Interface/Lobbies/LobbyTimerBehavior.gd").updateTime(self)

func shockwave():
	shockwaveAni.play("Tick")
	Sound.playSound(countdownSound)

func forceSpeedAnimation():
	if Game.combatTimer.getSpeed() != Game.combatTimer.MAX_SPEED:
		ObjectPool.playAnimation(forceSpeedAni, "ForceSpeed", Game.combatUINode)

func setFont(font, color):
	return load("res://Runtime/Behavior/Interface/Lobbies/LobbyTimerBehavior.gd").setFont(self, font, color)

func startProgressAni():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd").startProgressAni(self)

func animateProgress(duration: float):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd").animateProgress(self, duration)

func showWaitLabel(showWait: bool):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd").showWaitLabel(self, showWait)

func _physics_process(delta):
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd")._physics_process(self, delta)

func allEndResultsReceived():
	timerActive = false
	animation.play("HideTimer")

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		combatNode.queue_free()

func disable():
	Util.disconnectAll(self)
	timerActive = false
	animation.play("HideTimer")
	Util.callDelayed_process(self, "queue_free", 1)

func onReadyPressed():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd").onReadyPressed(self)

func updateReadyCounter():
	return load("res://Runtime/Behavior/Features/Interface/Lobbies/LobbyTimerBehavior.gd").updateReadyCounter(self)

func getCurTime() -> float:
	return snapped(preciseTime - BASETIME, 0.01)
