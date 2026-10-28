extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/PatchNotes.gd")

static func init(subject: Receiver) -> void :
	subject.get_node("Version").text = "Version " + str(Game.VERSION) + Game.SUBVERSION

	subject.label = subject.get_node("RichTextLabel")

	if Game.PREVIEW:
		subject.label.text = "This is still a preview version. The changelog is coming soon! :)"
	elif Game.BETA:
		subject.label.text = "Have fun testing! If you encounter bugs, let us know on our Discord."

	elif Game.DEMO:
		subject.label.text = subject.demoPatchnotes
	elif Util.later(Game.VERSION, Game.getPatchNoteVersion()):

		Game.setPatchNoteVersion(Game.VERSION)

		if Game.getNumStartedRuns() > 0:
			InputBlocker.activate(InputBlocker.Source.Popup)
			Util.callDelayed(subject, "open", 3.0)

	Game.connect("warp_cursor_menu", Callable(subject, "onCursorWarp"))

static func open(subject: Receiver):
	if not Game.draggedItem and not subject.is_inside_tree():
		Game.UINode.add_child(subject)
		Game.openMenu()
		Game.pause(Game.PauseSource.PatchNotes)
		subject.animation.play("Open")

		Util.localizeFonts(subject.label)

		if Game.PLAYTEST:
			subject.label.text = subject.english
		else:
			if TranslationServer.get_locale() == "zh_Hans_CN":
				subject.label.text = subject.chinese
			elif TranslationServer.get_locale() == "ja":
				subject.label.text = subject.japanese
			else:
				subject.label.text = subject.english

static func onClosePressed(subject: Receiver):
	if subject.animation.current_animation == "":
		subject.animation.play("Close")
		Game.onClickButton()
		Game.closeMenu(false)
		InputBlocker.activate(InputBlocker.Source.Popup)
