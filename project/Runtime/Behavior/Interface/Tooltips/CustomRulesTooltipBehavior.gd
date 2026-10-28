extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Tooltips/CustomRulesTooltip.gd")

static func updateRules(subject: Receiver, _customRules):
	if _customRules == null:
		_customRules = CustomRules
	for rule in CustomRules.Rules.values():
		if _customRules.isRuleDefault(rule):
			subject.entries[rule].hide()
		else:
			subject.entries[rule].show()

	subject.bonusGoldLabel.text = Util.addPlus(_customRules.getBonusGold())
	subject.treasureLimitLabel.text = Util.addPlus(_customRules.getRuleValue(CustomRules.Rules.TreasureLimit))
	subject.bonusTreasuresLabel.text = Util.addPlus(_customRules.getBonusUniqueChance()) + "%"
	subject.saleChanceLabel.text = Util.addPlus(_customRules.getRuleValue(CustomRules.Rules.SalesChance)) + "%"
	subject.tradeChanceLabel.text = Util.addPlus(_customRules.getRuleValue(CustomRules.Rules.TradeChance)) + "%"
	subject.healthMultiplierLabel.text = str(_customRules.getHealthMultiplier()) + "%"
	subject.cannotPickBagsCheckbox.set_pressed_no_signal(_customRules.getCannotPickBags())

	if not subject.lobbyMode:
		var leagueToMatch = _customRules.getLeagueToMatch()
		if leagueToMatch != _customRules.UNRANKED:
			subject.leagueToMatchRect.texture = Game.leagueIcons[leagueToMatch]

	subject.vboxcontainer.size.y = 0
