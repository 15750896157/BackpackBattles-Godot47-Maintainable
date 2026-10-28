extends Node2D

@onready var label = $RichTextLabel
@onready var animation = $AnimationPlayer
@onready var closeButton = $CloseButton
@onready var english = label.text

@export_multiline var demoPatchnotes: String = ""
@export_multiline var chinese: String = ""
@export_multiline var japanese: String = ""

func init() -> void :
	load("res://Runtime/Behavior/Features/Interface/PatchNotesBehavior.gd").init(self)

func open():
	return load("res://Runtime/Behavior/Features/Interface/PatchNotesBehavior.gd").open(self)

func animationFinished(_aniName):
	InputBlocker.deactivate(InputBlocker.Source.Popup)

func onClosePressed():
	return load("res://Runtime/Behavior/Features/Interface/PatchNotesBehavior.gd").onClosePressed(self)

func onCloseFinished():
	Game.unpause(Game.PauseSource.PatchNotes)
	Game.onPatchNotesClosed()
	get_parent().remove_child(self)

func onCursorWarp():
	if is_inside_tree() and closeButton != null:
		Game.addControlOfInterest(closeButton)
