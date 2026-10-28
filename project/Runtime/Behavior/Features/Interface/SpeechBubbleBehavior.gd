extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/SpeechBubble.gd")

static func say(subject: Receiver, text, presentTime: float, tutorialStep):
	if presentTime < 0:
		presentTime = subject.textbox.basePresentTime
	if subject.animation.current_animation == "" and not subject.isSpeaking():

		subject.curTutorialStep = tutorialStep
		subject.showTextbox(text, presentTime)
	else:
		Util.callDelayed(subject, "say", 0.5, [text, presentTime, tutorialStep])

static func showTextbox(subject: Receiver, text, presentTime):
	subject.textbox.show()
	subject.speaking = true
	subject.sequenceNumber += 1
	subject.textbox.set_end(Vector2(subject.textbox.get_end().x, subject.textbox.position.y))
	subject.textbox.showText("[riseup]" + text, presentTime)
	Util.callNextFrame(subject, "actuallyShowTextbox", [subject.sequenceNumber])

static func actuallyShowTextbox(subject: Receiver, forSequenceNumber):
	if subject.sequenceNumber != forSequenceNumber: return
	Util.callNextFrame(subject, "resizeTextbox")
	subject.animation.play("Show")
	if subject.curTutorialStep != null:
		subject.tutorialAnimation.play("Idle")
		Game.connect("tutorial_done", Callable(subject, "onTutorialDone"))

static func resizeTextbox(subject: Receiver):
	var numLines = round(subject.textbox.size.y / 34.0)
	Util.eassert(numLines - 1 < subject.bubbles.size())
	numLines = clamp(numLines, 1, subject.bubbles.size())

	subject.speechBubble.texture = subject.bubbles[numLines - 1]

static func onAnimationFinished(subject: Receiver, aniName):
	if aniName == "Hide":
		subject.speaking = false
		subject.tutorialAnimation.play("RESET")
		subject.curTutorialStep = null
		subject.emit_signal("closed")
		Util.tryDisconnect(Game, "tutorial_done", subject, "onTutorialDone")
		subject.textbox.hide()
