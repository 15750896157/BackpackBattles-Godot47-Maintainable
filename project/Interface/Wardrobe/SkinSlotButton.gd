extends Control

const notEnoughTrophiesLabel = preload("res://Interface/NotEnoughTrophiesLabel.tscn")
const normalTex = preload("res://Interface/Wardrobe/SkinSlotButton.png")
const hoverTex = preload("res://Interface/Wardrobe/SkinSlotButton_hovered.png")

const trophyParticles = preload("res://Interface/TrophyParticles.tscn")
const buySound1 = preload("res://Assets/Sound/Glitter.wav")
const buySound2 = preload("res://Assets/Sound/Bell.wav")
const notEnoughTrophiesSound = preload("res://Assets/Sound/Fanfare_sadtoot.ogg")

@onready var icon = $Icon
@onready var button = $Button
@onready var lock = $Locked

var skin: CharacterSkin
var slot: int
var notEnoughTrophiesReadyTime = 0.0

var hovered = false
var selected = false
var unlocked = false

func init(_skin: CharacterSkin, _slot: int):
	return load("res://Runtime/Behavior/Interface/Wardrobe/SkinSlotButtonBehavior.gd").init(self, _skin, _slot)

func setDisabled():
	icon.hide()
	lock.hide()

func preview():
	Game.PLAYER.sprite.setSkin(slot, skin.id)

func select():

	selected = true
	icon.show()

func deselect():
	selected = false
	icon.hide()

func onMouseEntered():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	onHover()
	if not unlocked:
		Game.wardrobe.showPriceTag(skin.prices[slot])

func onHover():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	preview()
	button.texture_normal = hoverTex
	Game.wardrobe.onSlotHovered(self)

func onHoverEnd():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	button.texture_normal = normalTex
	Game.wardrobe.onSlotUnhovered(self)

func onPressed():
	if not is_instance_valid(Game.wardrobe) or not Game.wardrobe.is_ancestor_of(self): return
	return load("res://Runtime/Behavior/Interface/Wardrobe/SkinSlotButtonBehavior.gd").onPressed(self)

func setLocked():
	unlocked = false
	lock.show()

func setUnlocked():
	unlocked = true
	lock.hide()

func unlock():
	return load("res://Runtime/Behavior/Interface/Wardrobe/SkinSlotButtonBehavior.gd").unlock(self)

