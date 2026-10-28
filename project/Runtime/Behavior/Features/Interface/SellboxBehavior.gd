extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Sellbox.gd")

static func onItemPickedUp(subject: Receiver):
	if Game.state != Game.State.Shop: return

	if Game.draggedItem.canBeSold():
		subject.set_process(true)
		subject.hintArea.hide()
		subject.label.show()
		subject.animation.stop()
		subject.updateText()
		subject.tradeNode.updateColor(Game.draggedItem)
		subject.chompParticles.emitting = false

static func chomp(subject: Receiver):
	Sound.playSound(subject.chompSound, - 10 + Util.randRange( - 3, 1), Util.randPitch(0.2))
	Util.callDelayed(Sound, "playSound", 0.2,
		[subject.closeSound, - 2, Util.randPitch(0.2)])

static func getTradeChance(subject: Receiver) -> float:
	if Expedition.enabled: return 0.0
	subject.tradeChance = 0.0
	subject.tradeBonusValue = 0

	subject.emit_signal("calc_trade_chance")

	var chance = subject.tradeChance

	if CustomRules.customRulesActive:
		chance += CustomRules.getRuleValue(CustomRules.Rules.TradeChance) / 100.0

	return chance

static func onShopRefreshed(subject: Receiver):
	if Game.itemsAreFusing:
		Game.connect("crafting_finished", Callable(subject, "rollTrades").bind(), subject.CONNECT_ONE_SHOT)
	else:
		subject.rollTrades()
