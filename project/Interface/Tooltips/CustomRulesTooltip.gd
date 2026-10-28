extends ToolTip

var lobbyMode: bool

@onready var entries = {
	CustomRules.Rules.BonusGold: $VBoxContainer/Gold,
	CustomRules.Rules.BonusTreasures: $VBoxContainer/Uniques,
	CustomRules.Rules.HealthMultiplier: $VBoxContainer/Health,
	CustomRules.Rules.SalesChance: $VBoxContainer/Sales,
	CustomRules.Rules.TradeChance: $VBoxContainer/Trade,
	CustomRules.Rules.TreasureLimit: $VBoxContainer/TreasureLimit,
	CustomRules.Rules.CannotPickBags: $VBoxContainer/CannotPickBags,
	CustomRules.Rules.LeagueToMatch: get_node_or_null("VBoxContainer/League"),
	CustomRules.Rules.SwitchMode: get_node_or_null("VBoxContainer/SwitchMode")
}

@onready var bonusGoldLabel = $VBoxContainer/Gold/Value
@onready var bonusTreasuresLabel = $VBoxContainer/Uniques/Value
@onready var treasureLimitLabel = $VBoxContainer/TreasureLimit/Value
@onready var saleChanceLabel = $VBoxContainer/Sales/Value
@onready var tradeChanceLabel = $VBoxContainer/Trade/Value
@onready var healthMultiplierLabel = $VBoxContainer/Health/Value
@onready var cannotPickBagsCheckbox = $VBoxContainer/CannotPickBags/Checkbox

@onready var leagueToMatchNode = get_node_or_null("VBoxContainer/League")
@onready var leagueToMatchRect = get_node_or_null("VBoxContainer/League/TextureRect")

func setRules(_customRules = null, _lobbyMode: bool = false):
	if _customRules == null:
		_customRules = CustomRules
	lobbyMode = _lobbyMode
	if lobbyMode:
		leagueToMatchNode.hide()
	updateRules(_customRules)

func updateRules(_customRules = null):
	return load("res://Runtime/Behavior/Interface/Tooltips/CustomRulesTooltipBehavior.gd").updateRules(self, _customRules)

