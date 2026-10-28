extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/RarityHint.gd")

static func updateLocale(subject: Receiver):
	subject.raritiesLabel = subject.get_node("Rarities")
	subject.fractionsLabel = subject.get_node("Fractions")
	subject.saleUniqueLabel = subject.get_node("SaleUnique")

	var text = ""
	for rarityI in range(0, Item.Rarity.Unique):
		text += Util.wrapInColor(Item.getRarityName(rarityI),
			Game.rarityColors[rarityI].lightened(0.2))
		if TranslationServer.get_locale() == "fr":
			text += Util.nonBreakingSpace
		text += ":\n"
	text = text.trim_suffix("\n")
	subject.raritiesLabel.text = text

static func onShopOpened(subject: Receiver):
	subject.fractionsLabel.text = "[right]"
	for fraction in Game.shopSceneNode.getRarityOddsForCurRound():
		subject.fractionsLabel.text += str(fraction * 100.0) + "%\n"
	subject.fractionsLabel.text = subject.fractionsLabel.text.trim_suffix("\n")

	if (Game.getNumStartedRuns() >= 3 and
		Game.getNumStartedRuns() < 10 and
		not Game.isTutorialDone(Game.TutorialSteps.ShopSign)):

		subject.tutorialAni.play("Tutorial")
