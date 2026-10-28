extends Node2D

@onready var sheet = $Sheet/Sheet
@onready var animation = $AnimationPlayer
@onready var vbox = $Sheet/VBoxContainer
@onready var label = $Sheet/VBoxContainer/RichTextLabel
@onready var cancelButton = $Sheet/VBoxContainer/CancelButton
@onready var confirmButton = $Sheet/VBoxContainer/ConfirmButton

func open(textKey, confirmKey, cancelKey):
	return load("res://Runtime/Callbacks/Interface/CallbacksB.gd").ForBoughtNothingWarning.open(self, textKey, confirmKey, cancelKey)

func close():
	if visible and animation.current_animation == "":
		animation.play("Hide")

func onClosed():
	Game.unpause(Game.PauseSource.RecipeBook)
	get_parent().remove_child(self)

func onCancelPressed():
	close()

func onConfirmPressed():
	close()
	Game.switchToCombat()
