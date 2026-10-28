extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForLeagueProgressUI:
	const Receiver = preload("res://Interface/LeagueProgressUI.gd")

	static func updateUI(subject: Receiver, charClass):
		subject.rankingLabel.text = str(Game.getRanking(charClass))
		var league = Game.getLeague(charClass)
		subject.leagueLabel.text = Game.getLeagueName(league)
		subject.leagueLabel.set("theme_override_colors/font_color", Game.leagueColors[league])
		subject.leagueProgressBar.material.set_shader_parameter("progress", Game.getLeagueProgress(charClass))
		subject.emblem.setLeague(league)
		subject.leagueProgressBar.modulate = Game.leagueColors[league]
