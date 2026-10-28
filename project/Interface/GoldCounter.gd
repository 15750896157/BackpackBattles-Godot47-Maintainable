extends "res://Interface/MovingCounter.gd"

const positiveChangeColor = Color(0.639343, 1, 0.392578)
const negativeChangeColor = Color(1, 0.392578, 0.392578)

@onready var bonusCounter = get_parent().get_node("GoldBonus")
@onready var tooltipArea = $TooltipArea

var lastChangeTime = 0.0
var lastChange = 0

func _ready() -> void :
	super._ready()
	Game.PLAYER.connect("class_changed", Callable(self, "updateInstant"))
	Game.connect("run_started", Callable(self, "updateTooltip").bind(2))
	Game.connect("gold_changed", Callable(self, "updateCounting"))
	Game.connect("round_start_gold_gained", Callable(self, "showBonus"))
	Game.connect("run_over", Callable(self, "updateTooltip").bind(2))
	updateInstant()
	Game.connect("continue_loaded", Callable(self, "updateFromRunstate"))

func updateFromRunstate():
	if Game.hasArenaRunState():
		updateTooltip(Game.arenaRunState["round"] + 1)
	else:
		updateTooltip(2)

func showBonus(_bonus):
	updateTooltip(Game.curRound + 1)

func updateTooltip(forRound):
	return load("res://Runtime/Behavior/Features/Interface/GoldCounterBehavior.gd").updateTooltip(self, forRound)

func updateInstant():
	setCurrent(Game.getGold())

func updateCounting(change):
	return load("res://Runtime/Behavior/Features/Interface/GoldCounterBehavior.gd").updateCounting(self, change)

func bonusFinishedCounting():
	bonusCounter.hide()
