extends Node2D

const particlesScene = preload("res://Interface/GlowingConfetti.tscn")

@onready var itemNameLabel = $ItemName
@onready var itemRect = $ItemRect
@onready var rectSize = itemRect.size
@onready var recordStar = $Star
@onready var categoryLabel = $Category
@onready var counterLabel = $Counter
@onready var timer = $Timer
@onready var animation = $AnimationPlayer
@onready var nextButton = $NextButton
@onready var previousButton = $PreviousButton

var statisticKeys = {
	Game.ItemStatistic.SeenInShop: "RECORD_Shop",
	Game.ItemStatistic.Acquired: "RECORD_Acquired",
	Game.ItemStatistic.BoughtOnSale: "RECORD_Sale",
	Game.ItemStatistic.Survivals: "RECORD_Survivals",
	Game.ItemStatistic.MostWins: "RECORD_Wins",
	Game.ItemStatistic.BestRankSurvival: "STATS_Rank",
}

var firstTimeKeys = {
	Game.ItemStatistic.Survivals: "RECORD_FirstSurvival"
}

var recordQueue: Array
var curRecord: int = 0

func _ready():
	load("res://Runtime/Behavior/Interface/RunAchievementBehavior.gd")._ready(self)

func open():
	return load("res://Runtime/Behavior/Interface/RunAchievementBehavior.gd").open(self)

func close():
	if visible:
		timer.stop()
		animation.play("Close")

func onTimeout():
	if recordQueue.size() == 1: return
	timer.start(3)
	showNext()

func onShowNextPressed():
	if recordQueue.size() == 1: return
	timer.stop()
	timer.start(5)
	showNext()

func onShowPreviousPressed():
	if recordQueue.size() == 1: return
	timer.stop()
	timer.start(5)
	showPrevious()

func showNext():
	curRecord = (curRecord + 1) % recordQueue.size()
	updateRecord()

func showPrevious():
	curRecord = (curRecord + recordQueue.size() - 1) % recordQueue.size()
	updateRecord()

func updateRecord():
	return load("res://Runtime/Behavior/Interface/RunAchievementBehavior.gd").updateRecord(self)

func onCursorWarp():
	if visible:
		Game.addControlOfInterest(nextButton)
		Game.addControlOfInterest(previousButton)
