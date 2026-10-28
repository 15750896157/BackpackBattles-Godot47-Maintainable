extends Node2D

@onready var defaultButton = $Default
@onready var bagLayerButton = $BagLayer
@onready var itemLayerButton = $ItemLayer

func _ready():
	return load("res://Runtime/Behavior/Features/Interface/EditModeButtonsBehavior.gd")._ready(self)

func _unhandled_input(event):
	return load("res://Runtime/Behavior/Features/Interface/EditModeButtonsBehavior.gd")._unhandled_input(self, event)

func isInteractable() -> bool:
	return ( not InputBlocker.isActive() and
			Game.draggedItem == null and
			Game.isShopActive())

func onDefaultPressed():
	return load("res://Runtime/Behavior/Features/Interface/EditModeButtonsBehavior.gd").onDefaultPressed(self)

func onBagLayerPressed():
	return load("res://Runtime/Behavior/Features/Interface/EditModeButtonsBehavior.gd").onBagLayerPressed(self)

func onItemLayerPressed():
	return load("res://Runtime/Behavior/Features/Interface/EditModeButtonsBehavior.gd").onItemLayerPressed(self)

func onEditModeChanged():
	return load("res://Runtime/Behavior/Features/Interface/EditModeButtonsBehavior.gd").onEditModeChanged(self)

