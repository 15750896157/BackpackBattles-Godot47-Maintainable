extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForItemFilterButton:
	const Receiver = preload("res://Interface/ItemLibrary/ItemFilterButton.gd")

	static func toggleGroup(subject: Receiver):
		var invertMode = subject.button_pressed

		if subject.button_pressed:
			for sibling in subject.siblings:
				if sibling.button_pressed:
					invertMode = false
					break
		if invertMode:
			subject.button_pressed = false
			for sibling in subject.siblings:
				sibling.button_pressed = true
		else:
			subject.button_pressed = true
			for sibling in subject.siblings:
				sibling.button_pressed = false

class ForItemRecordIcons:
	const Receiver = preload("res://Interface/ItemLibrary/ItemRecordIcons.gd")

	static func setItem(subject: Receiver, item: Item):
		subject.star.setItem(item)

		var bestRankSurvival = Game.getItemStatistics(Game.ItemStatistic.BestRankSurvival,
			item.descriptor)

		if bestRankSurvival != null:
			subject.rankLabel.show()
			subject.leagueSprite.show()
			subject.rankLight.show()
			var ranking = snapped(bestRankSurvival, 0.01)
			subject.rankLabel.text = str(int(fmod(ranking, 1.0) * 100.0))
			subject.leagueSprite.texture = Game.leagueIcons[int(ranking)]
			subject.rankLight.self_modulate = Game.leagueColors[int(ranking)]

class ForItemRecordStar:
	const Receiver = preload("res://Interface/ItemLibrary/ItemRecordStar.gd")

	static func setStarType(subject: Receiver, starType: int):
		if starType != - 1:
			subject.starSprite.show()
			subject.starLight.show()
			subject.starSprite.texture = subject.stars[starType]
			subject.starSprite.modulate = Color.WHITE
			subject.starLight.self_modulate = subject.lightColors[starType]
		else:
			if subject.showEmptyStar:
				subject.starLight.hide()
				subject.starSprite.show()
				subject.starSprite.texture = subject.stars[Game.ItemRecordStar.Bronze]
				subject.starSprite.modulate = subject.noStarModulate

	static func setItem(subject: Receiver, item: Item):

		var wins = Game.getItemStatistics(Game.ItemStatistic.MostWins,
			item.descriptor, 0)
		if wins == Game.MAX_ROUNDS:
			subject.setStarType(Game.ItemRecordStar.Diamond)
		elif wins == Game.MAX_ROUNDS - 1:
			subject.setStarType(Game.ItemRecordStar.Gold)
		else:
			var survivals = Game.getItemStatistics(Game.ItemStatistic.Survivals,
				item.descriptor, 0)
			if survivals > 0:
				subject.setStarType(Game.ItemRecordStar.Silver)
			elif wins >= Game.MAX_WINS:
				subject.setStarType(Game.ItemRecordStar.Bronze)
			else:
				subject.setStarType( - 1)
