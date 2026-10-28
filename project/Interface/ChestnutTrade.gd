extends Node2D

@onready var wantItemNode = $Node2D/Item1
@onready var giveItemNode = $Node2D/Item2
@onready var bubble = $Node2D/ThinkBubble1
@onready var animation = $AnimationPlayer
@onready var idleAnimations = [
	$Node2D/IdleAnimation,
	$ThinkBubble2/IdleAnimation,
	$ThinkBubble3/IdleAnimation]

var wantItem = null
var giveItem = null
var active = false

@onready var tradeExcludeItems = {
	ItemBook.chessboardDescriptor: true,
	ItemBook.deckOfCardsDescriptor: true
}

func _ready():
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd")._ready(self)

func onReturnToTitle():
	z_index = 4
	call_deferred("endTrade")

func onShopOpened():
	z_index = 35

func onShopClosed():
	endTrade()

func isTradeActive() -> bool:
	return active

func isTradable(item) -> bool:
	return isTradeActive() and item.isA(wantItem.descriptor)

func setTrade(wantItemIndex, giveItemIndex, giveData):
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd").setTrade(self, wantItemIndex, giveItemIndex, giveData)

func startTrade(bonusValue: int):
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd").startTrade(self, bonusValue)

func initItem(descriptor, parent):
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd").initItem(self, descriptor, parent)

func clearItem(item, instant: bool):
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd").clearItem(self, item, instant)

func getTradeGiveData():
	if not isTradeActive(): return null

	if ItemBook.isRing(giveItem):
		return giveItem.getData()

	return null

func onItemHovered(item):
	item.hover()

func onItemHoverEnd(item):
	item.hoverEnd()

func endTrade():
	if active:
		active = false
		animation.play("EndTrade")
		for ani in idleAnimations:
			ani.stop()

func reset():
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd").reset(self)

const darkColor = Color(0.880859, 0.860786, 0.830967)

func updateColor(item = null):
	return load("res://Runtime/Behavior/Interface/ChestnutTradeBehavior.gd").updateColor(self, item)

func onCursorWarp():
	if active:
		Game.addPointOfInterest(wantItem.global_position)
		Game.addPointOfInterest(giveItem.global_position)
