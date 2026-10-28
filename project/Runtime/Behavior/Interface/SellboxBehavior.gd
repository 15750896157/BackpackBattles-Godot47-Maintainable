extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Sellbox.gd")

static func _ready(subject: Receiver) -> void :
	Game.SELLBOX = subject
	subject.label.hide()
	Game.connect("item_picked_up", Callable(subject, "onItemPickedUp"))
	Game.connect("item_dropped", Callable(subject, "onItemDropped"))
	Game.connect("switch_to_shop", Callable(subject, "onSwitchingToShop"))
	Game.connect("returned_to_title", Callable(subject, "onShopLeft"))
	Game.connect("combat_scene_entered", Callable(subject, "onShopLeft"))
	Game.connect("run_over", Callable(subject, "onRunOver"))
	Game.shopSceneNode.connect("shop_refreshed", Callable(subject, "onShopRefreshed"))
	subject.set_process(false)
	subject.hintArea.show()
	subject.hint.hide()

static func onItemDropped(subject: Receiver, item, dropResult):

	if Item.wasHotSwap(dropResult):
		subject.tradeNode.updateColor(Game.draggedItem)
		return

	subject.hovered = false
	subject.set_process(false)
	subject.label.hide()
	subject.hintArea.show()
	subject.tradeNode.updateColor(null)
	subject.lightTween = Util.refreshTween(subject.lightTween)
	subject.lightTween.tween_property(subject.light, "modulate:a", 0.0, 0.2)
	subject.hoverParticles.deactivate()
	subject.modulate = Color.WHITE

	if dropResult != Item.DropResult.Sold:
		subject.angleTween = Util.refreshTween(subject.angleTween)
		subject.angleTween.tween_property(subject.chestnutTop, "rotation_degrees", subject.closedAngle, 0.2)
	else:
		subject.animation.play("Sell")
		subject.soldRoll[item.descriptor] = Game.shopSceneNode.rollsThisRun

static func eatGold(subject: Receiver, amount):
	subject.animation.stop()
	Sound.playSound(subject.chompSound, - 4 + Util.randRange( - 1, 1), Util.randPitch(0.2))
	if amount == 1:
		subject.animation.play("EatCoin")
		Util.callDelayed(Sound, "playSound", 0.5,
			[subject.coinEatSound_single, - 4, Util.randPitch(0.2)])
	else:
		subject.animation.play("EatGold")
		Util.callDelayed(Sound, "playSound", 0.5,
			[subject.coinEatSound_many, - 4, Util.randPitch(0.2)])

static func _process(subject: Receiver, delta: float) -> void :
	var mousePos = Util.getMousePosInWindow()
	var dist = (mousePos - subject.box.global_position).length()
	var angle = subject.angleCurve.sample(dist / subject.closedDist)
	var dif = angle - subject.chestnutTop.rotation_degrees
	subject.chestnutTop.rotation_degrees += sign(dif) * min(abs(dif), subject.maxAnglePerSecond * delta)

	subject.hovered = subject.rect.has_point(mousePos)
	if subject.hovered != subject.hoveredLastFrame:
		subject.lightTween = Util.refreshTween(subject.lightTween)
		if subject.hovered:
			subject.lightTween.tween_property(subject.light, "modulate:a", 1.0, 0.05)
			subject.modulate = Color(1.2, 1.2, 1.0)
			subject.hoverParticles.activate()
		else:
			subject.lightTween.tween_property(subject.light, "modulate:a", 0.0, 0.05)
			subject.modulate = Color.WHITE
			subject.hoverParticles.deactivate()
		subject.updateText()
		subject.tradeNode.updateColor(Game.draggedItem)
	subject.hoveredLastFrame = subject.hovered

static func updateText(subject: Receiver):
	var rawText
	if subject.tradeNode.isTradeActive() and Game.draggedItem.isA(subject.tradeNode.wantItem.descriptor):
		if subject.hovered:
			subject.label.translationKey = "HINT_Trade2"
		else:
			subject.label.translationKey = "HINT_Trade1"
	else:
		if subject.hovered:
			subject.label.translationKey = "HINT_Sell3"

		else:
			subject.label.translationKey = "HINT_Sell2"

		var baseSellPrice = Game.draggedItem.getBaseSellPrice()
		var sellPrice = Game.draggedItem.getSellPrice()

		var priceStr: String
		if baseSellPrice > sellPrice:
			priceStr = Util.wrapInColor(str(sellPrice), Util.red)
		else:
			priceStr = Util.wrapInColor(str(sellPrice), Util.paramColor)

		subject.label.formatParams = {"price": priceStr + Util.imageToBbcode(subject.coinSpritePath, 44)}

	subject.label.updateLocale()

static func sellItem(subject: Receiver, item):
	if item.pve_is_view():
		if not bool(item.get_meta("pve_sell_committed", false)): return
		if bool(item.get_meta("pve_sale_presented", false)): return
		item.set_meta("pve_sale_presented", true)
		Expedition.transitions.sell(subject, item, int(item.get_meta("pve_sell_price", 0)))
		return
	if subject.tradeNode.isTradeActive():
		if item.isA(subject.tradeNode.wantItem.descriptor):
			Sound.playSound(subject.openSound)
			Util.reparentNode(item, Game.shopItemYSort)
			var itemTween = subject.create_tween()
			itemTween.tween_property(item, "global_position",
				subject.bottomPos.global_position, 0.5)

			var giveItem = ItemBook.generateAndStorageItem(subject.tradeNode.giveItem.descriptor,
				subject.bottomPos.global_position + Vector2(30, - 30), Game.STORAGEBOX.center - Vector2(0, 150))

			if ItemBook.isRing(giveItem):
				giveItem.copyFrom(subject.tradeNode.giveItem)

			subject.tradeNode.endTrade()
			subject.tradeAnimation.play("Trade")

			giveItem.animation.play("FromTrade")
			return

	Util.reparentNode(item, Game.shopItemYSort)
	var price = item.getSellPrice()
	Game.gainGold(price)
	Game.onItemSold(item)
	var itemTween = subject.create_tween()
	itemTween.tween_property(item, "global_position",
		subject.bottomPos.global_position, 0.5)
	Sound.playSound(subject.openSound)

	if price > 0:
		var coinParticles = Game.shootGold(subject.getGoldPos(),
			Game.PLAYER.getGoldPos(), price)
		coinParticles.z_index = Game.getCoinSellboxLayer()
		Util.setDelayed(coinParticles, "z_index", Game.getCoinPlayerLayer(), 0.5)
		Util.callDelayed(Sound, "playSound", 0.5, [subject.coinSpitSound])

static func _gui_input(subject: Receiver, event):
	if (event is InputEventMouseButton and
		event.is_pressed() and
		Game.draggedItem == null and
		not Util.isTweenRunning(subject.clickTween)):

		var strength = 1.0
		if event.button_index == MOUSE_BUTTON_RIGHT:
			strength = 2.0

		var dur = 0.2 + 0.1 * strength
		var phase1Dur = dur * 0.5
		var jumpPos = subject.defaultPos.y + Util.rng.randf_range( - 15, - 25) * strength
		subject.clickTween = Util.refreshTween(subject.clickTween)
		subject.clickTween.set_parallel()
		subject.clickTween.tween_property(subject.chestnut, "position:y", jumpPos,
			phase1Dur).set_ease(Tween.EASE_OUT)
		subject.clickTween.tween_property(subject.chestnut, "position:y",
			subject.defaultPos.y, dur - phase1Dur).from(jumpPos
			).set_delay(phase1Dur).set_ease(Tween.EASE_IN)

		var angle = Util.rng.randf_range( - 0.1, 0.2) * strength
		subject.clickTween.tween_property(subject.chestnut, "rotation", angle,
			phase1Dur).set_ease(Tween.EASE_OUT)
		subject.clickTween.tween_property(subject.chestnut, "rotation", 0.0,
			dur - phase1Dur).from(angle).set_delay(phase1Dur).set_ease(Tween.EASE_IN)

		subject.clickTween.tween_callback(Callable(subject, "spawnDust").bind(strength)).set_delay(dur - 0.1)

		Sound.playSound(subject.jumpSound, 0 + (strength - 1) * 3, 0.8)

static func spawnDust(subject: Receiver, strength):
	var particles1 = ObjectPool.particleOneShot(subject.dustParticlesScene, subject)
	particles1.position = Vector2( - 58, 100)
	particles1.scale.x = 0.4
	particles1.amount = 3 + 2 * strength

	var particles2 = ObjectPool.particleOneShot(subject.dustParticlesScene, subject)
	particles2.position = Vector2(26, 100)
	particles2.scale.x = - 0.4
	particles2.amount = 3 + 2 * strength

	Sound.playSound(subject.jumpSound, 0 + (strength - 1) * 3, 0.3)
