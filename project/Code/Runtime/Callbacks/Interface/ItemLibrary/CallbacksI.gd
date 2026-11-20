extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.
## 2026-11-20 ui_converge1: removed dead classes ForItemFilterButton / ForItemRecordIcons
## (their receivers ItemFilterButton.gd / ItemRecordIcons.gd retired with the old item library panel).

class ForItemRecordStar:
	const Receiver = preload("res://PvE/UI/ItemLibrary/ItemRecordStar.gd")

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
