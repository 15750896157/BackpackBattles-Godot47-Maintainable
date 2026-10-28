extends "res://Interface/MovingCounter.gd"

@onready var bonusCounter = get_parent().get_node("HealthBonus")
@onready var tooltipArea = $TooltipArea

func _ready() -> void :
	super._ready()
	Game.PLAYER.connect("class_changed", Callable(self, "updateInstant"))
	Game.PLAYER.connect("max_health_changed_ui", Callable(self, "updateInstant"))
	if Expedition.enabled:
		Game.PLAYER.connect("health_changed_ui", Callable(self, "updateInstant"))
		offset_right = -8.0
		horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bonusCounter.hide()
		updateTooltip(0)

	Game.connect("round_start_health_gained", Callable(self, "showBonus"))
	Game.connect("run_over", Callable(self, "updateTooltip").bind(2))
	updateInstant()
	Game.connect("continue_loaded", Callable(self, "updateFromRunstate"))

func updateFromRunstate():
	updateTooltip(0)
	updateInstant()
	return

func updateInstant():
	setCurrent(Game.PLAYER.getMaxHealth())

func updateLabel():
	if Expedition.enabled and is_instance_valid(Game.PLAYER):
		text = "%d/%d" % [roundi(Game.PLAYER.getCurrentHealth()), roundi(Game.PLAYER.getMaxHealth())]
		return
	super.updateLabel()

func updateTooltip(forRound):
	tooltipArea.params = {}
	if is_instance_valid(tooltipArea.tooltip):
		tooltipArea.tooltip.set_meta("pve_description_key", "ui.persistent_health_hint")
	return

func showBonus(amount):
	bonusCounter.hide()
	updateInstant()
	return

func bonusFinishedCounting() -> void :
	bonusCounter.hide()
