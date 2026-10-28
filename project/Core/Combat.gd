extends Node2D

const winSound = preload("res://Assets/Sound/Victory.mp3")
const loseSound = preload("res://Assets/Sound/Fanfare_loss.mp3")
const glitterSound = preload("res://Assets/Sound/Confetti2.ogg")
const trophyScene = preload("res://Interface/Trophy.tscn")
const trophySound = preload("res://Assets/Sound/Bell2.mp3")
const survivalSound = preload("res://Assets/Sound/Fatigue.wav")
const rankUpPulse = preload("res://Interface/RankUpPulse.tscn")
const rankUpParticles = preload("res://Interface/LeagueChangeParticles.tscn")
const rankDownParticles = preload("res://Interface/RankDownParticles.tscn")
const rankUpSound = preload("res://Assets/Sound/RankUp.ogg")
const rankUpSound2 = preload("res://Assets/Sound/RankUp2.ogg")
const rankDownSound = preload("res://Assets/Sound/RankDown.ogg")
const combatStartSound = preload("res://Assets/Sound/Drumroll.ogg")
const clipMaterial = preload("res://Shader/MaskClip.material")
const eatTrophyParticles = preload("res://Interface/Combat/EatTrophyParticles.tscn")
const chestnutLandSound = preload("res://Assets/Sound/Impact.ogg")
const swordClashSound = preload("res://Assets/Sound/SwordClash.mp3")

@onready var UI = $UI
@onready var hideTimer = $HideTimer
@onready var runAnimation = $RunAnimation
@onready var roundAnimation = $RoundAnimation
@onready var roundIdleAnimation = $RoundAnimationIdle
@onready var rankedNode = $UI/Ranked
@onready var rankedAnimation = $UI/Ranked/RankedAnimation
@onready var chestnut = $UI/Chestnut
@onready var chestnutPos = $UI/Chestnut/Marker2D
@onready var chestnutAnimation = $UI/Chestnut/ChestnutAnimation
@onready var trophyCounter = $UI/Chestnut/BottomFront/TrophyCounter
@onready var backgroundAnimation = get_node_or_null("Background/BackgroundAnimation")
@onready var animationTimer = $AnimationTimer
@onready var rankingCounter = $UI/Ranked/Ranking
@onready var rankingDiff = $UI/Ranked/Dif
@onready var rankingDiffAnimation = $UI/Ranked/Dif/AnimationPlayer
@onready var leagueLabel = $UI/Ranked/League
@onready var leagueEmblem = $UI/Ranked/LeagueEmblem
@onready var leagueProgressBar = $UI/Ranked/LeagueProgressBar
@onready var leagueProgressBarMaterial = leagueProgressBar.material
@onready var barBorderParticles = $UI/Ranked/BarBorderParticles
@onready var emblemAnimation = $UI/Ranked/LeagueEmblem/AnimationPlayer
@onready var emblemParticles = $UI/Ranked/EmblemParticles
@onready var bonusAnimation = $BonusAnimationPlayer
@onready var bonusTrophyParticles = $"UI/10Wins/TrophyParticles"
@onready var autobattlerHintAni = $AutobattlerHint/AnimationPlayer
@onready var triesLeftLabel = $UI/TriesLeft/TriesLeftLabel
@onready var aboveUINode = $AboveUI
@onready var hideUIButton = $AboveUI/HideUIButton
@onready var currentStats = $AboveUI/CurrentStats
@onready var roundResultLabel = $AboveUI/CurrentStats/RoundResult
@onready var triesNode = $AboveUI/CurrentStats/HBoxContainer/Tries
@onready var customRulesIcon = $AboveUI/CurrentStats/CustomRulesIcon
@onready var unrankedBanner = $AboveUI/CurrentStats/UnrankedBanner
@onready var unrankedLabel = $AboveUI/CurrentStats/Unranked
@onready var leagueEmblem2 = $AboveUI/CurrentStats/LeagueEmblem
@onready var rankLabel = $AboveUI/CurrentStats/Rank
@onready var rankUpBonusAnimation = $UI/Ranked/BonusAnimationPlayer
@onready var rankUpBonusLabel = $UI/Ranked/RankUpBonus
@onready var combatLogButton = $CombatLogButtonNode/CombatLogButton
@onready var survivalPrompt = $"%SurvivalPrompt"
@onready var survivalPromptAnimation = survivalPrompt.get_node("AnimationPlayer")
@onready var survivalHealHint = survivalPrompt.get_node("StartSurvival/HealHint")
@onready var survivalTrophies = $UI/Trophies/SurvivalTrophies
@onready var surviveRoundsCounterAnimation = $UI/SurviveRoundsCounter/AnimationPlayer
@onready var surviveRoundsCounterLabel = $UI/SurviveRoundsCounter/Label
@onready var surviveRoundsCounter = $UI/SurviveRoundsCounter
@onready var subclassRoundHealLabel = $UI/SubclassHealLabel
@onready var subclassRoundHealAnimation = $UI/SubclassHealLabel/AnimationPlayer
@onready var animationTween = $AnimationTween
@onready var runOverLabel = $"%RunOverLabel"
@onready var backgroundNode = $Background
@onready var darkLayer = $UI/ColorRect
@onready var chestnutPupil = $UI/Chestnut/BottomFront/Top/Eye/Pupil

@onready var winParticles1 = $UI/WinParticles1
@onready var winParticles2 = $UI/WinParticles2
@onready var loseParticles1 = $UI/LoseParticles1
@onready var loseParticles2 = $UI/LoseParticles2

@onready var lobbyResultAni = $UI/LobbyResult/AnimationPlayer
@onready var lobbyResultScoreLabel = $UI/LobbyResult/Result_Score
@onready var lobbyResultRankLabel = $UI/LobbyResult/Result_Rank
@onready var lobbyTrophyPosition = $UI/LobbyResult/TrophyPosition

var lobbyResultsReceived = false
var buildViewer = null

var phase = Phase.Combat
var trophies = []
var hearts = []
var lobbyTrophies = []
var result
var curRanking
var postCombatBgmStarted = false
var animatedTime = 0.0
var survivalPromptActive = false
var clippedNodes = []
var pve_lifecycle_epoch: int = 0

enum Phase{
	Combat = 0,
	OffScreen = 1,
	RoundResult = 2,
	RoundResultSkippable = 3,
	RunResult = 4,
	RunResultSkippable = 5,
}

const NUM_TROPHIES_OVERRIDE = 16

func _ready() -> void :
	load("res://Runtime/Behavior/Core/CombatBehavior.gd")._ready(self)

func ready_deferred():
	if Game.LOBBIES_ENABLED:
		RunDatabase.lobbies.connect("all_end_results_received", Callable(self, "onLobbyResultsReceived"))

func onSwitchingToCombat():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").onSwitchingToCombat(self)

func onSwitchedToCombat():
	combatLogButton.disabled = false
	combatLogButton.show()

func clashSwords():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").clashSwords(self)

func pve_clash_swords(epoch: int, opponent_id: int):
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").pve_clash_swords(self, epoch, opponent_id)

func pve_reset_lifecycle():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").pve_reset_lifecycle(self)

func onCombatStart():
	phase = Phase.Combat

func onCombatEnd(roundResult):
	Expedition.render_state()
	return

func reactToRoundResult():
	Expedition.render_state()
	return

func popInTrophy():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").popInTrophy(self)

func loseHeart():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").loseHeart(self)

func playGlitterSound():
	Sound.playSound(glitterSound, - 5, Util.rng.randf_range(0.9, 1.1))

func playTrophySound():
	Sound.playSound(trophySound)

func startRoundResultSkippable():
	phase = Phase.RoundResultSkippable
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void :
	load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd")._unhandled_input(self, event)

func skipIfPossible():
	if UI.visible:
		if phase == Phase.RoundResultSkippable:
			skipRoundResult()
		elif phase == Phase.RunResultSkippable:
			skipRunResult()

func skipRoundResult():
	Expedition.advance_result()
	return

func hideRoundResultAndSwitchBackToShop():
	hideRoundResult()
	switchBackToShop()

func hideRoundResult():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").hideRoundResult(self)

func switchBackToShop():
	Expedition.advance_result()
	return

func switchAway():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").switchAway(self)

func switchBackToBuildHistory():
	hideRoundResult()

	Game.buildHistory.open(true)
	switchAway()

func showSurvivalPrompt():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").showSurvivalPrompt(self)

func cancelSurvivalMode():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").cancelSurvivalMode(self)

func cancelSurvivalMode_continue():
	skipRoundResult()

func refillHeart():
	if Game.getTries() < Game.MAX_TRIES:
		hearts[Game.getTries()].heal()

func loseAndRefillHeart():
	if Game.getTries() < Game.MAX_TRIES:
		hearts[Game.getTries()].loseAndHealBack()

func startSurvivalMode():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").startSurvivalMode(self)

func startSurvivalMode_continue():
	skipRoundResult()
	roundAnimation.play("WinHide")
	switchBackToShop()

func updateSurvivalCounter():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").updateSurvivalCounter(self)

func hideTimerTimeout():

	hide()
	chestnutPupil.deactivate()

func startClipping():
	set_process(true)

	for node in clippedNodes:
		node.set_material(clipMaterial)

	Util.callDelayed(self, "stopClipping", 1)

func stopClipping():
	set_process(false)

	for node in clippedNodes:
		node.set_material(null)

	hideUIButton.hideButton()

func _process(delta):
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd")._process(self, delta)

func endRun():
	Expedition.render_state()
	return

func isARankedMode() -> bool:
	return Game.curMode == Game.Mode.Ranked or Game.wasRankedSwitchMode

func instanceLobbyTrophies():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").instanceLobbyTrophies(self)

func givePerfectRunBonus():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").givePerfectRunBonus(self)

func giveMaxWinsBonus():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").giveMaxWinsBonus(self)

func playRankedAnimation():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").playRankedAnimation(self)

const TROPHY_MOVE_DUR = 1.0
const TROPHY_DELAY = 0.1

func feedTrophies():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").feedTrophies(self)

func onTrophyFed():
	chestnutAnimation.stop()
	chestnutAnimation.play("EatTrophy")
	ObjectPool.particleOneShot(eatTrophyParticles, chestnut)

func trophiesFinished():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").trophiesFinished(self)

func rankingDiffCountingFinished():
	rankingDiffAnimation.play("Hide")

const BASE_LEAGUE_BAR_DURATION = 1.0
const RELATIVE_LEAGUE_BAR_DURATION = 1.0

func setNewRanking(leagueExact):
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").setNewRanking(self, leagueExact)

func setLeagueProgress(progress: float):
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").setLeagueProgress(self, progress)

func stopParticles():
	barBorderParticles.emitting = false

func setLeague(league):
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").setLeague(self, league)

func updateLeague(league, rankedUp, ranking):
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").updateLeague(self, league, rankedUp, ranking)

func startRunResultSkippable():
	phase = Phase.RunResultSkippable
	set_process_unhandled_input(true)

func skipRunResult():
	Expedition.return_to_title()
	return

func reset():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").reset(self)

func clearParticles():
	for particles in [winParticles1, winParticles2, loseParticles1, loseParticles2]:
		particles.restart()
		particles.emitting = false

func hideUI():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").hideUI(self)

func showUI():
	UI.show()
	onShowUI()
	Game.combatLog.close()
	if survivalPromptActive:
		survivalPrompt.show()

func isPostCombatScreenVisible() -> bool:
	return darkLayer.is_visible_in_tree()

func onShowUI():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").onShowUI(self)

func stopTimeTween():
	animationTween.stop_all()
	animationTween.remove_all()

const ADVANCE_SPEED = 5.0

func advanceTime(time):
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").advanceTime(self, time)

func onAnimationTimerTimeout():
	if not is_instance_valid(backgroundAnimation): return
	backgroundAnimation.speed_scale = 1.0
	backgroundAnimation.seek(Game.combatTimer.getEffectiveTime())

func interpolateTime(time):
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").interpolateTime(self, time)

func setTime(time):

	animatedTime = time
	if not is_instance_valid(backgroundAnimation): return
	backgroundAnimation.seek(Game.COMBAT_DELAY + animatedTime, true)

func forceSwitchToShop():
	Expedition.enter_shop()
	return

func forceReturnToTitle():
	Expedition.return_to_title()
	return

func onLobbyResultsReceived():
	lobbyResultsReceived = true
	if phase == Phase.RunResult:
		showLobbyResults()

func showLobbyResults():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").showLobbyResults(self)

func onLobbyFinishButtonPressed():
	return load("res://Runtime/Behavior/Features/Core/CombatBehavior.gd").onLobbyFinishButtonPressed(self)

func playDropSound():
	pass

func playLandSound():
	Sound.playSound(chestnutLandSound)

func playOpenSound():
	Sound.playSound(Game.SELLBOX.openSound)

func playCloseSound():
	Sound.playSound(Game.SELLBOX.closeSound)

@onready var combatTimerNodes = [Game.combatTimer.fastButton,
	Game.combatTimer.pauseButton, Game.combatTimer.speedSlider]

func onCursorWarp():
	return load("res://Runtime/Behavior/Core/CombatBehavior.gd").onCursorWarp(self)

