extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/RankSeason3Popup.gd")

static func _ready(subject: Receiver):
	Game.pause(Game.PauseSource.PatchNotes)
	subject.animation.play("Open")
	subject.animation.advance(0.01)

	subject.particles = subject.trophyRainParticles.instantiate()
	subject.get_parent().add_child(subject.particles)

	var bonusTrophies = 50

	for oldRankEmblem in subject.get_node("Node2D/OldRanks").get_children():
		var classI = Game.getClassEnum()[oldRankEmblem.name]
		var newRankEmblem = subject.get_node("Node2D/NewRanks").get_node(NodePath(str(oldRankEmblem.name)))

		var rating = Game.getRunRating(classI, "2")
		var leagueExact = Game.getLeague_exact(rating)
		var league = int(leagueExact)

		bonusTrophies += league * 10

		var rating2 = Game.getRunRating(classI, "3")
		var newLeagueExact = Game.getLeague_exact(rating2)

		oldRankEmblem.setLeague(classI, leagueExact)
		newRankEmblem.setLeague(classI, newLeagueExact)

	subject.trophyLabel.formatParams = {"num":
		str("[b]", Util.highlight(bonusTrophies), "[/b]")}
	subject.trophyLabel.updateText()

	Game.giveTrophies(bonusTrophies)
	Game.saveGame()

static func close(subject: Receiver):
	subject.animation.play("Close")
	subject.particles.emitting = false

	var tween = subject.create_tween()
	tween.tween_property(subject.particles, "speed_scale", 3.0, 0.5)

	Util.callDelayed(subject.particles, "queue_free", 10)
