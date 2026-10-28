extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForBoughtNothingWarning:
	const Receiver = preload("res://Interface/BoughtNothingWarning.gd")

	static func open(subject: Receiver, textKey, confirmKey, cancelKey):
		Game.UINode.add_child(subject)
		Game.pause(Game.PauseSource.RecipeBook)
		subject.animation.play("Show")
		subject.label.translationKey = textKey
		subject.label.updateLocale()
		subject.cancelButton.translationKey = cancelKey
		subject.cancelButton.updateLocale()
		if confirmKey:
			subject.confirmButton.show()
			subject.confirmButton.translationKey = confirmKey
			subject.confirmButton.updateLocale()
		else:
			subject.confirmButton.hide()
