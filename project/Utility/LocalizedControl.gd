extends Control
class_name LocalizedControl

@export var translationKey = ""
@export var prefix = ""
@export var suffix = "" # (String, MULTILINE)
@export var capslock = false
@export var autoMaxSize = false
@export var maxSize = 0.0
@export var maxSizeY = 0.0
@export var removeBreaks = false
@export var shrinkLimit = 4

var poolingHandle

var fonts = Dictionary()
var modern_font_sizes = Dictionary()
var shrink: bool

var refPos: Vector2

var formatParams = null

func preset():
	pass

func setMaxSize(_maxSize):
	maxSize = _maxSize

func _init():
	set_message_translation(false)

func _ready() -> void :
	load("res://Runtime/Behavior/Utility/LocalizedControlBehavior.gd")._ready(self)

func collectFonts():
	return load("res://Runtime/Behavior/Utility/LocalizedControlBehavior.gd").collectFonts(self)

func updateLocale():
	collectFonts()
	updateText()

func setTranslationKey(_translationKey: String):
	translationKey = _translationKey
	updateText()

func updateText():
	return load("res://Runtime/Behavior/Utility/LocalizedControlBehavior.gd").updateText(self)

func isAutoWrapping() -> bool:
	return ("autowrap_mode" in self and get("autowrap_mode") != TextServer.AUTOWRAP_OFF) or is_class("RichTextLabel")

func returnToObjectPool():

	for path in fonts:
		var font = fonts[path]
		if font == null: continue
		set(path, font)
	ObjectPool.returnInstance(self)

func shrinkIfTooBig(newText):
	return load("res://Runtime/Behavior/Utility/LocalizedControlBehavior.gd").shrinkIfTooBig(self, newText)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		Util.removeLocalizedNode(self)
