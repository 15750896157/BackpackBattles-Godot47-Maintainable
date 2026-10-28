extends Node2D

signal closed

const bubbles = [
	preload("res://Assets/Shop/Shopkeeper/Speechbubble4.png"),
	preload("res://Assets/Shop/Shopkeeper/Speechbubble3.png"),
	preload("res://Assets/Shop/Shopkeeper/Speechbubble2.png"),
	preload("res://Assets/Shop/Shopkeeper/Speechbubble1.png"),
	preload("res://Assets/Shop/Shopkeeper/Speechbubble5.png"),
	preload("res://Assets/Shop/Shopkeeper/Speechbubble6.png")
]

const tutorialDoneSound = preload("res://Assets/Sound/Chime2.mp3")

var speaking = false
var sequenceNumber = 0
var curTutorialStep
@onready var speechBubble = $Speechbubble
@onready var textbox = $RichTextLabel
@onready var font = textbox.get("theme_override_fonts/normal_font")
@onready var animation = $AnimationPlayer

@onready var tutorialAnimation = $Tutorial/AnimationPlayer

func _ready() -> void :
	get_viewport().connect("size_changed", Callable(self, "resizeTextbox"))

func say(text, presentTime: float = -1.0, tutorialStep = null):
	return load("res://Runtime/Behavior/Features/Interface/SpeechBubbleBehavior.gd").say(self, text, presentTime, tutorialStep)

func getSequenceNumber():
	return sequenceNumber

func showTextbox(text, presentTime):
	return load("res://Runtime/Behavior/Features/Interface/SpeechBubbleBehavior.gd").showTextbox(self, text, presentTime)

func actuallyShowTextbox(forSequenceNumber):
	return load("res://Runtime/Behavior/Features/Interface/SpeechBubbleBehavior.gd").actuallyShowTextbox(self, forSequenceNumber)

func resizeTextbox():
	return load("res://Runtime/Behavior/Features/Interface/SpeechBubbleBehavior.gd").resizeTextbox(self)

func onTextFinished():
	animation.play("Hide")

func onAnimationFinished(aniName):
	return load("res://Runtime/Behavior/Features/Interface/SpeechBubbleBehavior.gd").onAnimationFinished(self, aniName)

func isSpeaking() -> bool:
	return speaking

func shutUp():
	textbox.stop()
	onTextFinished()

func onTutorialDone(stepDone):
	if stepDone == curTutorialStep:
		tutorialAnimation.play("Check", 0.3)
		Sound.playSound(tutorialDoneSound)
		curTutorialStep = null

func isGivingTutorial() -> bool:
	return curTutorialStep != null
