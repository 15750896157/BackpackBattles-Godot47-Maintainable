extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForWishlistButton:
	const Receiver = preload("res://Interface/WishlistButton.gd")

	static func _ready(subject: Receiver) -> void :
		if Game.TRAILER or Game.PLAYTEST or Game.FULLVERSION:
			subject.hide()
		else:
			if subject.localize:
				subject.add_to_group("Localized")
				Util.localizeFonts(subject.label)
				subject.updateLocale()

class ForWishlistPopup:
	const Receiver = preload("res://Interface/WishlistPopup.gd")

	static func close(subject: Receiver):
		if subject.animation.current_animation == "":
			subject.animation.play("Close")
			Sound.playSound_process(subject.openSound, 0, 1.3)
			await subject.animation.animation_finished
			Game.unpause(Game.PauseSource.Options)
			subject.emit_signal("closed")
			subject.queue_free()
