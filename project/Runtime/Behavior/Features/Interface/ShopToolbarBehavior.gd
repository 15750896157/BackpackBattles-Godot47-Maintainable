extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/ShopToolbar.gd")

static func unhide(subject: Receiver):
	subject.show()
	subject.tween = Util.refreshTween(subject.tween)
	var height = subject.closedY
	if subject.isOpen:
		height -= subject.openHeight
	subject.tween.tween_property(subject, "position:y", height, 0.15)

static func onCombatToShop(subject: Receiver):
	subject.position.y = subject.closedY + subject.hiddenHeight
	subject.position.x = subject.xPos
	subject.unhide()

	if (Game.getNumStartedRuns() > 3 and
		not Game.isTutorialDone(Game.TutorialSteps.Toolbar)):

		subject.tutorialAni.play("Tutorial")

static func close(subject: Receiver):
	subject.isOpen = false
	subject.toolbarButton.flip_v = false
	subject.tween = Util.refreshTween(subject.tween)
	subject.tween.tween_property(subject, "position:y", subject.closedY, 0.1)
	subject.tween.tween_callback(Callable(subject, "closeFinished"))

static func onPushToStoragePressed(subject: Receiver):
	if not subject.isInteractable(): return

	Game.cancelSwitch()
	Game.STORAGEBOX.pushAllToStorage()
	Sound.playSound(subject.windSound)
	if Util.time >= subject.particleReadyTime:
		ObjectPool.particleOneShot(subject.windParticles, subject.get_parent())
		subject.particleReadyTime = Util.time + 0.2

static func onCursorWarp(subject: Receiver):
	if subject.isOpen:
		for button in subject.buttons:
			Game.addPointOfInterest(button.global_position + button.size * 0.5)

	else:
		Game.addPointOfInterest(subject.toolbarButton.global_position + subject.toolbarButton.size * 0.5)
