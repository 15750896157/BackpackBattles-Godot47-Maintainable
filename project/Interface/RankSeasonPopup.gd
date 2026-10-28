extends Node2D

@onready var animation = $AnimationPlayer
@onready var trophyLabel = $Node2D/TrophyLabel

func _ready():
	load("res://Runtime/Callbacks/Interface/CallbacksR.gd").ForRankSeasonPopup._ready(self)

func close():
	animation.play("Close")

func onClosed():
	Game.unpause(Game.PauseSource.PatchNotes)
	queue_free()
