extends Control
class_name ToolTip

enum Alignment{
	Top = 0,
	Center = 1,
	Bottom = 2
}

const keywords = [
	"spikes", "vampirism", "poison", "regen", "bl", "lucky",
	"stun", "blind", "blindingLight", "reflect", "mana", "heat",
	"cold", "empower", "rage", "empty", "affected", "fatigue",
	"treasure", "charge"
]

const centerStr = "[center]"
const referenceTextFormat = "{prefix}[sc len={length} color=#{color}]{replacement}[/sc]{suffix}"
const referenceImageFormat = "{prefix}{img}{suffix}"

var triggerColor_html = Util.triggerColor.to_html(false)

@onready var vboxcontainer = $VBoxContainer
@onready var nameLabel = get_node_or_null("VBoxContainer/Name")

const Y_OFFSET = 0
@export var Y_BORDER = 120
var MARGIN = 8
@export var SCREEN_MARGIN = Vector2.ZERO

func _ready():
	hide()

func updateSize():
	return load("res://Runtime/Behavior/Interface/Tooltips/TooltipBehavior.gd").updateSize(self)

func forceUpdate():
	var parent = get_parent()
	parent.remove_child(self)
	parent.add_child(self)
	show()
	updateSize()
	Util.callNextFrame(self, "updateSize")

func align(toolPos: Vector2, toolSize: Vector2, alignment):
	return load("res://Runtime/Behavior/Interface/Tooltips/TooltipBehavior.gd").align(self, toolPos, toolSize, alignment)

func setPosition(toolPos: Vector2, toolSize: Vector2, alignment = Alignment.Center):
	updateSize()
	align(toolPos, toolSize, alignment)
	updateSize()

func forceUpdatePosition(toolPos: Vector2, toolSize: Vector2, alignment = Alignment.Center):
	setPosition(toolPos, toolSize, alignment)
	forceUpdate()

	call_deferred("setPosition", toolPos, toolSize, alignment)

func onTagHoverStart(_tag):
	pass

func onTagHoverEnd(_tag):
	pass

func replaceReferences(text, iconSize = null):
	return load("res://Runtime/Behavior/Interface/Tooltips/TooltipBehavior.gd").replaceReferences(self, text, iconSize)

static func findClosingBracket(inText: String, fromPos: int) -> int:
	return load("res://Runtime/Behavior/Interface/Tooltips/TooltipBehavior.gd").findClosingBracket(inText, fromPos)

static func highlight(text: String, wave = false, bold = false) -> String:
	return load("res://Runtime/Behavior/Interface/Tooltips/TooltipBehavior.gd").highlight(text, wave, bold)

func discard():
	Util.removeLocalizedNode(self)
	queue_free()
