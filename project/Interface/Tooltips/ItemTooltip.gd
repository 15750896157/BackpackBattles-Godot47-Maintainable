extends ToolTip
class_name ItemToolTip

enum TextEffect{
	None = 0,
	Water = 1,
	Spooky = 2,
	Shaky = 3,
	Ice = 4,
	Fire = 5,
	Rainbow = 6,
	Vampiric = 7,
	Gold = 8,
	Light = 9,
	Nature = 10,
	Magic = 11,
	Lightning = 12,
	Stompy = 13,
	Mercury = 14,
	Steel = 15,
	Dog = 16,
	Dog2 = 17,
	Spring = 18,
	Hyper = 19,
	Stone = 20,
	Poison = 21,
	NotSet = - 1
}

const propertyScene = preload("res://Interface/Tooltips/TooltipProperty.tscn")

const descriptionScene = preload("res://Interface/Tooltips/Description.tscn")
const dividerScene = preload("res://Interface/Tooltips/TooltipDivider.tscn")
const typeIconScene = preload("res://Interface/Tooltips/TypeIcon.tscn")
const classIconScene = preload("res://Interface/Tooltips/ClassIcon.tscn")

const MAX_MOUSE_SPEED = 15.0

var poolingHandle

var animation
var propertyContainer
var hboxContainer
var marginContainer
var descrLabel
var rarityLabel
var typeLabel
var typesContainer
var extraTypesLabel
var spacer2
var divider1
var divider2

var item
var properties: Dictionary
var references = []
var sizeChanged: bool
var toReturn = []
var stackDescriptionNodes = []
@onready var framesUntilVisible = 0

@onready var subDescriptionPosition = marginContainer
@onready var propPosition = nameLabel

static func highlight(text: String, _wave = false, _bold = false):
	var paramColor = Color(1, 0.890196, 0.219608)
	if Expedition.enabled: paramColor = Color("74410f")
	return Util.wrapInColor_fixed(text, paramColor)

func preset():
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").preset(self)

const bagEffectIcon = "[i][img=0x28]res://Interface/Tooltips/AffectsInside.png[/img][/i]"

func setItem(_item):
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").setItem(self, _item)

func _set_pve_identity():
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd")._set_pve_identity(self)

func fixSpillingTypes():
	if hboxContainer.size.x > 470:
		typeLabel.hide()
		extraTypesLabel.show()
		extraTypesLabel.text = typeLabel.text + " " + extraTypesLabel.text

func removeStackDescriptions():

	if vboxcontainer.size.y > 900:
		for node in stackDescriptionNodes:
			node.hide()
			size.y -= node.size.y

func updateTooltip(init: bool = false):
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").updateTooltip(self, init)

func _pve_number(value: float) -> String:
	return String.num(value, 2).trim_suffix(".00").trim_suffix(".0")

func _update_pve_properties():
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd")._update_pve_properties(self)

func addReferenceExplanations(refs):
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").addReferenceExplanations(self, refs)

func addSubDescription(text: String, darken: bool):
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").addSubDescription(self, text, darken)

func addProperty(stat: int, _name, value, modified: int,
	perSecond = null, perSecondModified = 0):
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").addProperty(self, stat, _name, value, modified, perSecond, perSecondModified)

const latinPunctuationCharacters = [".", ",", ":", ")"]

const punctuationCharacters = {
	"zh_Hans_CN": ["。", "，", "：", "）"],
	"zh_Hant_TW": ["。", "，", "：", "）"]
}

func scolor_movePunctuation(text):
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").scolor_movePunctuation(self, text)

func _physics_process(delta):
	framesUntilVisible -= 1
	if framesUntilVisible <= 0:
		set_physics_process(false)
		setVisible()

func setVisibleIn(frames):
	modulate = Color.TRANSPARENT
	framesUntilVisible = frames
	set_physics_process(true)

func setVisible():
	modulate = Color.WHITE
	if Expedition.enabled:
		modulate.a = 0.0
		var appearance = create_tween().set_ignore_time_scale(true)
		appearance.tween_property(self,"modulate:a",1.0,0.08 if Expedition.preferences.values.get("reduce_motion",false) else 0.14)
	Game.lastShowItemTooltipFrame = Util.getFrameCounter_process()

func discard():
	return load("res://Runtime/Behavior/Interface/Tooltips/ItemTooltipBehavior.gd").discard(self)

