extends Node2D

signal closed

const openSound = preload("res://Audio/Sound/Swoosh1.wav")
const buttonScene = preload("res://UI/Interface/Wardrobe/SkinSlotButton.tscn")
const iconScene = preload("res://UI/Interface/Wardrobe/SkinHeader.tscn")

var playerZ
@onready var unlockHint = $UnlockHint
@onready var unlockHintLabel = $UnlockHint/Hint
@onready var priceTag = $UnlockHint/Price
@onready var hboxContainer = $ScrollContainer/HBoxContainer
@onready var animation = $AnimationPlayer
@onready var trophyCounter = $TrophyCounter
@onready var chibiButton = $ChibiButton

var skin_revision: int = 0
var skin_building: bool = false
var closing: bool = false
var model := preload("res://Code/Runtime/ViewModel/WardrobeVM.gd").new(Game, SkinBook)
var selectedSkins = []
var isOpen = false
var slotButtons = []
var closeButton: Button

func _ready():
	return load("res://Code/Runtime/Behavior/Interface/Wardrobe/WardrobeBehavior.gd")._ready(self)

func open():
	return load("res://Code/Runtime/Behavior/Interface/Wardrobe/WardrobeBehavior.gd").open(self)

func close():
	return load("res://Code/Runtime/Behavior/Features/Interface/Wardrobe/WardrobeBehavior.gd").close(self)

func _unhandled_input(event: InputEvent):
	if isOpen and Util.isActionPressed_event(event, "options"):
		get_viewport().set_input_as_handled()
		close()

func finishedClosing():
	isOpen = false
	Game.PLAYER.spriteNode.z_index = playerZ
	Game.titleScreen.classButtonsNode.z_index = 0
	if get_parent() != null: get_parent().remove_child(self)
	if Game.wardrobe == self: Game.wardrobe = null
	AssetStream.release("wardrobe")
	AssetStream.release("wardrobe-icons")
	AssetStream.release_metadata()
	queue_free()

func onCharacterSelected():
	if isOpen:
		initSkins()

func onSwitchStyle():
	if isOpen:
		initSkins()

func initSkins():
	return await load("res://Code/Runtime/Behavior/Interface/Wardrobe/WardrobeBehavior.gd").initSkins(self)

func getSlotButtons():
	return slotButtons

func selectAndPreviewSkinSlots():
	for slot in selectedSkins.size():
		var button = getSkinSlotButton(slot, selectedSkins[slot])
		if button == null: continue
		button.select()
		button.preview()

const skinSlotNodeFormat = "{skin}/{slot}"

func getSkinSlotButton(slot: int, skinId: int):
	return hboxContainer.get_node_or_null(skinSlotNodeFormat.format(
		{"skin": skinId, "slot": slot}))

func onSkinIconHovered(icon):
	return load("res://Code/Runtime/Behavior/Features/Interface/Wardrobe/WardrobeBehavior.gd").onSkinIconHovered(self, icon)

func onSkinIconUnhovered(icon):
	for slot in Game.SkinSlot.size():
		var button = getSkinSlotButton(slot, icon.skin.id)
		if button != null: button.onHoverEnd()

func onSkinIconSelected(icon):
	return load("res://Code/Runtime/Behavior/Features/Interface/Wardrobe/WardrobeBehavior.gd").onSkinIconSelected(self, icon)

func onSlotHovered(slotButton):
	unlockHint.global_position.y = min(slotButton.global_position.y, 900)

func onSlotUnhovered(slotButton):
	if closing or skin_building or slotButton.slot >= selectedSkins.size(): return
	var button = getSkinSlotButton(slotButton.slot, selectedSkins[slotButton.slot])
	if button != null: button.preview()
	unlockHint.hide()

func onSlotSelected(slotButton):
	return load("res://Code/Runtime/Behavior/Features/Interface/Wardrobe/WardrobeBehavior.gd").onSlotSelected(self, slotButton)

func showPriceTag(price: int):
	return load("res://Code/Runtime/Behavior/Interface/Wardrobe/WardrobeBehavior.gd").showPriceTag(self, price)

func updateHint():
	pass
