extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForPopupMessage:
	const Receiver = preload("res://Interface/PopupMessage.gd")

	static func setText(subject: Receiver, key: String):
		Util.localizeFonts(subject.label)
		subject.label.setTranslationKey(key)
		print("MSG: ", subject.label.text)
		subject.animation.play("Show")
		subject.timer.start(subject.duration)

class ForPullButton:
	const Receiver = preload("res://Interface/PullButton.gd")

	static func _physics_process(subject: Receiver, delta):
		if subject.disabled: return

		if subject.grabbed:
			var projection = (Util.getMousePosInWindow() - subject.clickOffset - subject.defaultPos).project(subject.pullVector)

			subject.progress = projection.x / subject.pullVector.x
		else:
			subject.progress -= delta / subject.movebackTime

		subject.progress = clamp(subject.progress, 0, 1)
		subject.global_position = subject.defaultPos + subject.progress * subject.pullVector

		if subject.grabbed and subject.progress >= 1:
			if subject.moveBackAfterTrigger:
				subject.grabbed = false
			subject.trigger()
		elif not subject.grabbed and subject.progress == 0:
			subject.set_physics_process(false)
			subject.deactivate()

class ForPushToStorageButton:
	const Receiver = preload("res://Interface/PushToStorageButton.gd")

	static func _unhandled_input(subject: Receiver, event):
		if InputBlocker.isActive(): return

		if (Game.draggedItem == null and
			Game.isShopActive() and
			Util.isActionPressed_event(event, "push_all_to_storage")):

			Game.cancelSwitch()
			subject.trigger()
			subject.disabled = true
			subject.grabbed = false
			Util.killTween(subject.pullTween)
			subject.pullTween = subject.create_tween()
			subject.pullTween.tween_property(subject, "global_position", subject.endPos, 0.1)
			subject.pullTween.tween_callback(Callable(subject, "tweenFinished"))

	static func trigger(subject: Receiver):
		subject.onHoverEnd()
		if not Game.draggedItem:
			Game.cancelSwitch()
			Game.STORAGEBOX.pushAllToStorage()
			Sound.playSound(subject.windSound)
			if Util.time >= subject.particleReadyTime:
				ObjectPool.particleOneShot(subject.windParticles, subject.get_parent())
				subject.particleReadyTime = Util.time + 0.2
