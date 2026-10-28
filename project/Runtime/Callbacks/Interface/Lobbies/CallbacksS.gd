extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForStartTimer:
	const Receiver = preload("res://Interface/Lobbies/StartTimer.gd")

	static func onTimeout(subject: Receiver):
		subject.animation.play("Count")
		subject.timeLeft -= 1
		if subject.timeLeft > 0:
			subject.timer.start(1.0)
			Sound.playSound(subject.tickSound)
		else:
			subject.emit_signal("countdown_ended")

		subject.timerLabel.text = str(subject.timeLeft)

class ForSwitchModeUnrankedUI:
	const Receiver = preload("res://Interface/Lobbies/SwitchModeUnrankedUI.gd")

	static func updateLocale(subject: Receiver):
		var enMargin = subject.localeMargins["en"]
		var margin = subject.localeMargins.get(TranslationServer.get_locale(), enMargin)
		var rules = subject.get_node("Rules")
		rules.offset_right = margin
		for rule in rules.get_children():
			var label = rule.get_node_or_null("Property")
			if label != null:
				label.setMaxSize(224 + margin - enMargin)
