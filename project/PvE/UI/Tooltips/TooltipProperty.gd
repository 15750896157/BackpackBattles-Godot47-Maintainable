extends HBoxContainer

const defaultSize = 230.0

var nameLabel
var poolingHandle
var valueLabel
var perSecondLabel
var iconSprite

func preset():
	nameLabel = $Name
	valueLabel = $Value
	perSecondLabel = $PerSecond
	iconSprite = $IconRect/Icon

func _ready():

	nameLabel.custom_minimum_size.x = defaultSize

func setTuple(_name: String, _value: String, modified: int, iconTex: Texture2D):
	if TranslationServer.get_locale() == "fr":
		nameLabel.text = str(_name, Util.nonBreakingSpace, ":")
	else:
		nameLabel.text = _name + ":"

	valueLabel.text = _value
	valueLabel.set("theme_override_colors/font_color", Util.statColors[modified])

	perSecondLabel.hide()

	iconSprite.texture = iconTex
	call_deferred("positionIcon")

func positionIcon():
	iconSprite.position.y = size.y * 0.5

func setPerSecond(_value: String, modified: int):
	perSecondLabel.show()
	perSecondLabel.text = _value
	perSecondLabel.set("theme_override_colors/font_color", Util.statColors[modified])

	var font = valueLabel.get_theme_font("font")
	var font_size = valueLabel.get_theme_font_size("font_size")
	var width = font.get_string_size(valueLabel.text + _value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if width.x > 185:
		shrink(width.x - 185)

func shrink(amount):
	nameLabel.custom_minimum_size.x = maxf(110,defaultSize - amount)
	nameLabel.size.x = nameLabel.custom_minimum_size.x
