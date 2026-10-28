extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForIngameCharacterHUD:
	const Receiver = preload("res://Interface/IngameCharacterHUD.gd")

	static func updateLabels(subject: Receiver):
		subject.triesNode.hide()
		subject.roundNode.position = Vector2(-44, 114)
		subject.winsNode.position = Vector2(-64, 155)
		subject.survivalSkull.hide()
		subject.surviveLabel.hide()
		subject.lobbyNode.hide()
		subject.rankingLabel.hide()
		subject.emblem.hide()
		subject.customRulesIcon.hide()
		subject.unrankedLabel.show()
		subject.unrankedLabel.translationKey = ""
		if Expedition.db != null:
			var difficulty = str(Expedition.flow.run.get("difficulty_id", Expedition.setup_difficulty))
			subject.unrankedLabel.text = Expedition.t("difficulty." + difficulty + ".name")
		return
