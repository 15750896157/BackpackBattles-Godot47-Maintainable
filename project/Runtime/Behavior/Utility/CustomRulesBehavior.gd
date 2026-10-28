extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Utility/CustomRules.gd")

static func pushRule(subject: Receiver, rule: int, bitStream: BitStream):
	var step: int = subject.STEP[rule]
	var encoded: int = subject.getRuleValue(rule) - subject.MIN[rule]
	Util.eassert(encoded % step == 0)
	encoded /= step
	var maxRange = subject.MAX[rule] - subject.MIN[rule]
	Util.eassert(maxRange % step == 0)
	maxRange /= step
	bitStream.push(encoded, maxRange + 1)

static func serialize(subject: Receiver) -> String:
	if not subject.customRulesActive:
		return ""
	Util.eprint("Serialize custom rules")
	var bitStream = BitStream.new()

	bitStream.push(subject.getLeagueToMatch() + 1, Game.Leagues.size())
	for rule in range(subject.Rules.BonusGold, subject.Rules.TradeChance + 1):
		subject.pushRule(rule, bitStream)
	bitStream.push(subject.getCannotPickBags(), 2)

	subject.pushRule(subject.Rules.SwitchMode, bitStream)

	return bitStream.toGodotString()

static func fromString(subject: Receiver, serialized: String):
	if serialized == "":
		Util.eprint("no custom rules")
		return

	var bitStream = BitStream.new()
	bitStream.fromGodotString(serialized)

	subject.setLeagueToMatch(bitStream.pull(Game.Leagues.size()) - 1)
	for rule in range(subject.Rules.BonusGold, subject.Rules.TradeChance + 1):
		subject.pullRule(rule, bitStream)
	subject.setCannotPickBags(bitStream.pull(2))

	subject.pullRule(subject.Rules.SwitchMode, bitStream)

	subject.customRulesActive = true

static func pullRule_noSet(subject: Receiver, rule: int, bitStream: BitStream):
	var maxRange = subject.MAX[rule] - subject.MIN[rule]
	maxRange /= subject.STEP[rule]
	return bitStream.pull(maxRange + 1) * subject.STEP[rule] + subject.MIN[rule]

static func isSwitchModeNoLoad(subject: Receiver, serialized: String) -> int:
	var bitStream = BitStream.new()
	bitStream.fromGodotString(serialized)

	bitStream.pull(Game.Leagues.size())
	for rule in range(subject.Rules.BonusGold, subject.Rules.TradeChance + 1):
		subject.pullRule_noSet(rule, bitStream)
	bitStream.pull(2)

	return subject.pullRule_noSet(subject.Rules.SwitchMode, bitStream)
