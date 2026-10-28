extends Node2D

const destructReactionScene = preload("res://Assets/Shop/Shopkeeper/DestructReaction.tscn")

const numTips = 12
var curTip = 0
var craftingTipShown = false
var craftNextRound = false
var showCraftFlavorText = false

@onready var hint = $ShopKeeperHint
@onready var head = $Shopkeeper/ShopkeeperHead

func _ready() -> void :
	load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd")._ready(self)

func updateLocale():
	hint.text = "[center]" + ToolTip.highlight(Util.tr_nbs("HINT_Shopkeeper"), true)

func onReturnToTitle():
	Game.speechBubble.z_index = 10

func onReturnedToTitle():
	Game.speechBubble.shutUp()

func onHover():

	if Game.draggedItem == null:
		hint.show()

func onHoverEnd():
	hint.hide()

func onShopkeeperClicked():
	return load("res://Runtime/Behavior/Features/Interface/ShopkeeperBehavior.gd").onShopkeeperClicked(self)

func onShopOpened():
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").onShopOpened(self)

func tutorial():
	return load("res://Runtime/Behavior/Features/Interface/ShopkeeperBehavior.gd").tutorial(self)

func onBuy_tutorial(item, onSale, sequenceNum):
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").onBuy_tutorial(self, item, onSale, sequenceNum)

func onLoss():
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").onLoss(self)

func onWin():
	return load("res://Runtime/Behavior/Features/Interface/ShopkeeperBehavior.gd").onWin(self)

func hello():
	Game.speechBubble.say(Util.tr_nbs("HELLO" + randNum(4)))

func helloAgain():
	Game.speechBubble.say(Util.tr_nbs("HELLO_AGAIN" + randNum(5)))

func onBuy(item, onSale):
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").onBuy(self, item, onSale)

func onSell(item):
	return load("res://Runtime/Behavior/Features/Interface/ShopkeeperBehavior.gd").onSell(self, item)

func onStartHovered():
	pass

func onStartPressed():
	say("START", 4)

func onCraftingReady():
	return load("res://Runtime/Behavior/Features/Interface/ShopkeeperBehavior.gd").onCraftingReady(self)

func onCraft(_itemDescriptor):
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").onCraft(self, _itemDescriptor)

func giveLockHint():
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").giveLockHint(self)

func randNum(numVariants: int) -> String:
	return str(Util.rng.randi_range(1, numVariants))

func say(code, numVariants):
	if Game.speechBubble.isSpeaking(): return
	Game.speechBubble.say(tr(code + randNum(numVariants)))

func onSpeechbubbleClosed():
	pass

var reaction = null
const reactionFormat = "[center][shake level={level}]{exclamation}"
const exclamations = ["?", "!", "?!", "??", "!!", "!?"]

func onDecorationDestructed():
	return load("res://Runtime/Behavior/Interface/ShopkeeperBehavior.gd").onDecorationDestructed(self)

