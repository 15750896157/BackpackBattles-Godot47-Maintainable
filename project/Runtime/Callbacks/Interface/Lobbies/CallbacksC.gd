extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForCustomUnrankedUI:
	const Receiver = preload("res://Interface/Lobbies/CustomUnrankedUI.gd")

	static func _ready(subject: Receiver):
		for button in subject.get_node("Leagues").get_children():
			subject.leagueButtons.push_back(button)
			button.button_group = subject.buttonGroup

			var league = Game.Leagues.get(button.name, - 1)
			button.connect("pressed", Callable(subject, "onLeagueSelected").bind(league))

	static func open(subject: Receiver):
		subject.show()
		for button in subject.leagueButtons:
			button.set_pressed_no_signal(false)
		var selectedLeague = CustomRules.getLeagueToMatch()
		subject.leagueButtons[selectedLeague + 1].set_pressed_no_signal(true)
		subject.customRulesInput.onOpen()
