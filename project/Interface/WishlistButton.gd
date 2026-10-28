extends Button

@export var localize = true
@export var onCharacter = false

const hoverColor = Color(1, 0.890196, 0.215686)

@onready var label = $Label

func _ready() -> void :
	load("res://Runtime/Callbacks/Interface/CallbacksW.gd").ForWishlistButton._ready(self)

func updateLocale():
	if onCharacter:
		label.text = tr("BUTTON_WishlistCharacter")
	else:
		label.text = tr("BUTTON_Wishlist")

func _pressed() -> void :
	Game.onClickButton()

	var res = Util.openLocalLink("steam://advertise/2427700")

	if res != OK:
		Util.openLocalLink("https://store.steampowered.com/app/2427700")

func onHover() -> void :
	label.set("theme_override_colors/font_color", hoverColor)
	Game.onHoverInteractable(self)

func onHoverEnd() -> void :
	label.set("theme_override_colors/font_color", Game.SOFTWHITE)
	Game.onHoverInteractableEnd(self)
