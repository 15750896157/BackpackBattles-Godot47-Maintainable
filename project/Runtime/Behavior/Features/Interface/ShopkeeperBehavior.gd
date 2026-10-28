extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Shopkeeper.gd")

static func onShopkeeperClicked(subject: Receiver):
	if Game.speechBubble.isSpeaking(): return

	Game.speechBubble.say(Util.tr_nbs("TIP" + str(subject.curTip)))
	subject.curTip = (subject.curTip + 1) % subject.numTips

static func tutorial(subject: Receiver):
	Game.speechBubble.say(Util.tr_nbs("TUTORIAL_BUY"), 30)
	Game.connect("item_bought", Callable(subject, "onBuy_tutorial").bind(
		Game.speechBubble.getSequenceNumber()), subject.CONNECT_ONE_SHOT)

static func onWin(subject: Receiver):
	var n = subject.randNum(15)
	var t = Util.tr_nbs("WON" + n)

	if n == "15":
		t = t.replace("$wins", str(Game.getNumWins()))

	Game.speechBubble.say(t)

static func onSell(subject: Receiver, item):
	if Game.speechBubble.isSpeaking(): return
	var rng = Util.rng.randf()
	if rng < 0.25:
		Game.speechBubble.say(Util.tr_nbs("SELL" + subject.randNum(5)).replace("$item", item.getTranslatedName(true)))

static func onCraftingReady(subject: Receiver):
	if not subject.craftingTipShown and Game.getNumCraftedItems() == 0:
		Game.speechBubble.shutUp()
		Game.speechBubble.say(Util.tr_nbs("CRAFTING1"), 8)
		subject.craftingTipShown = true
