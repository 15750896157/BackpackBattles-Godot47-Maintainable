extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Lobbies/OtherModesUI.gd")

static func open(subject: Receiver):
	if not Game.draggedItem and not subject.is_inside_tree():

		Game.titleScreen.add_child(subject)
		subject.isOpen = true
		subject.animation.play("Open")
		for ui in subject.UIs:
			ui.hide()
		subject.buttons.show()

		if Game.hasArenaRunState():
			subject.customUnrankedButton.disable()
			subject.switchModeRankedButton.disable()
			subject.switchModeUnrankedButton.disable()
		else:
			subject.customUnrankedButton.enable()
			subject.switchModeRankedButton.enable()
			subject.switchModeUnrankedButton.enable()
			subject.switchModeRankedLeague.updateUI(null)

		Util.updateLocaleInSubtree(subject)

static func close(subject: Receiver, cancel: bool):
	if cancel:
		CustomRules.reset()
		if Game.hasArenaRunState():
			Game.restoreCustomRules(Game.arenaRunState)

		subject.emit_signal("cancel")

	subject.animation.play("Close")
	Game.unhoverAndHideTooltips()
	InputBlocker.activate(InputBlocker.Source.Popup)
	Sound.playSound_process(Game.transitionSounds[1], 0, 1.2)
	subject.emit_signal("ui_closed")

static func _ready(subject: Receiver):
	for ui in subject.UIs:
		ui.connect("close_requested", Callable(subject, "close"))
		ui.hide()

	Game.connect("warp_cursor_title", Callable(subject, "onCursorWarp"))
	subject.add_to_group("Localized")

	Util.callNextFrame(subject, "ready_deferred")
