extends Node2D

const trophyRainParticles = preload("res://Interface/TrophyRainParticles.tscn")

@onready var animation = $AnimationPlayer
@onready var trophyLabel = $Node2D/TrophyLabel

var particles

func _ready():
	return load("res://Runtime/Behavior/Features/Interface/RankSeason3PopupBehavior.gd")._ready(self)

func close():
	return load("res://Runtime/Behavior/Features/Interface/RankSeason3PopupBehavior.gd").close(self)

func onClosed():
	Game.unpause(Game.PauseSource.PatchNotes)
	queue_free()
