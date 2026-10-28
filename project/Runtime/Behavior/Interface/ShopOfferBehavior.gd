extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/ShopOffer.gd")

static func _input(subject: Receiver, event: InputEvent) -> void :
	if Expedition.enabled and (event is InputEventJoypadButton or (is_instance_valid(Game.PLAYER) and Game.PLAYER.INVENTORY.pve_navigation_active)):
		return
	if InputBlocker.isActive(): return

	if (Util.isActionPressed_event(event, "reserve") and
		subject.canPlayerReserve() and
		Game.hasHoverFocus(subject.item)):
			subject.setReserved( not subject.reserved)
			if subject.reserved:
				Game.onItemReserved()

static func _ready(subject: Receiver) -> void :
	Game.connect("gold_changed", Callable(subject, "checkMoney"))
	subject.priceLabel.self_modulate = Color.TRANSPARENT
	subject.priceLabel.text = ""
	subject.light.self_modulate = Color.TRANSPARENT
	Util.localizeFonts(subject.subclassLabel)
	subject.add_to_group("Localized")

	subject.reserveButton.connect("mouse_entered", Callable(subject, "onReserveButtonHover"))
	subject.reserveButton.connect("mouse_exited", Callable(subject, "onReserveButtonHoverEnd"))
	subject.reserveButton.connect("pressed", Callable(subject, "onReserveButtonPressed"))

static func setItem(subject: Receiver, _item, _saleMode):
	subject.saleMode = _saleMode

	subject.animation.stop()

	if subject.bought or not subject.item:
		subject.animation.play("AppearFromNothing")
	else:
		subject.animation.play("AppearFromItem")
	subject.item = _item

	subject.bought = false

	subject.item.ownerType = Item.Owner.Shop
	Game.shopItemYSort.add_child(subject.item)

	subject.item.position = subject.global_position - subject.item.getBottomCenter() - Game.shopItemYSort.global_position
	subject.item.connect("dropped", Callable(subject, "dropped"))

	subject.light.modulate = subject.item.rarityColors[subject.item.getRarity()]

	if subject.item.getRarity() == Item.Rarity.Unique:
		subject.uniqueParticles.emitting = true

		if subject.item.descriptor.startsSubclass != "":
			subject.setBannerText(Game.getTranslatedSubclassName(subject.item.descriptor.startsSubclass))
			var mat = subject.classBannerMaterial.duplicate()
			subject.banner.set_material(mat)
			mat.set_shader_parameter("gradient", Util.bannerGradients[subject.item.descriptor.classes])
			mat.set_shader_parameter("gradient2", null)
			mat.set_shader_parameter("use2ndGradient", false)

			subject.subclassAnimation.play("Show")
			subject.addSpecialShopParticles()

		elif subject.item.hasType(Item.Type.Skill):
			subject.setBannerText(subject.item.getTranslatedName())
			if subject.item.descriptor.classes == ItemDescriptor.StuffedClasses.Neutral:
				subject.banner.set_material(subject.neutralBannerMaterial)
			else:
				var mat = subject.classBannerMaterial.duplicate()

				subject.banner.set_material(mat)
				var classesAsArr = subject.item.descriptor.getClassesAsArray()
				mat.set_shader_parameter("gradient", Util.bannerGradients[classesAsArr[0]])

				if classesAsArr.size() == 1:
					mat.set_shader_parameter("gradient2", null)
					mat.set_shader_parameter("use2ndGradient", false)

				else:
					mat.set_shader_parameter("gradient2", Util.bannerGradients[classesAsArr[1]])
					mat.set_shader_parameter("use2ndGradient", true)

					var xPos = subject.banner.global_position.x + subject.banner.size.x * 0.5
					xPos -= Game.shopSceneNode.position.x
					xPos /= 1920
					mat.set_shader_parameter("xPos", xPos)

			subject.subclassAnimation.play("Show")
			subject.addSpecialShopParticles()

		elif subject.item.descriptor.randomUniquePool:
			var ani = ObjectPool.instantiate(subject.treasureAnimation)
			ani.hide()
			subject.add_child(ani)
			ani.get_node("AnimationPlayer").play("Activate")
			ani.global_position = subject.item.global_position
			Sound.playSound(subject.treasureSound, 6)
	else:
		subject.uniqueParticles.emitting = false

	subject.calcPrice()
	subject.call_deferred("checkCrafting")

static func checkCrafting(subject: Receiver):
	if Expedition.enabled or not is_instance_valid(subject.item): return
	if subject.item.hasShopItemCraftCandidates():
		var pulse = ObjectPool.instantiate(subject.craftingPulse)
		subject.add_child(pulse)
		var ani = pulse.get_node("RevealPulse/AnimationPlayer")
		pulse.global_position = subject.item.global_position
		var speedFactor = Util.rng.randf_range(0.9, 1.1)
		ani.speed_scale = 0.7 * speedFactor
		ani.play("Activate")
		var scaling = 0.2 + (0.4 * sqrt(subject.item.getNumOccupiedCells()))
		pulse.scale = Vector2(scaling, scaling)
		subject.item.animation.play("ShopCraft", - 1, speedFactor)

static func setBannerText(subject: Receiver, text: String):

	subject.subclassLabel.autowrap_mode = TextServer.AUTOWRAP_OFF
	subject.subclassLabel.text = text

	var font = subject.subclassLabel.get_theme_font("font")
	var font_size = font.size if font is LegacyFont else subject.subclassLabel.get_theme_font_size("font_size")
	var textWidth = font.get_string_size(subject.subclassLabel.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if textWidth > subject.BANNER_WIDTH:
		subject.subclassLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		var spacePos = - 1

		var firstLineWidth = subject.BANNER_WIDTH
		while true:
			spacePos = text.find(" ", spacePos + 1)
			if spacePos == - 1:
				break

			var s = font.get_string_size(text.substr(0, spacePos + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if s > subject.BANNER_WIDTH:
				break
			else:
				firstLineWidth = s

		var secondLineWidth = textWidth - firstLineWidth + 10
		textWidth = max(firstLineWidth, secondLineWidth)

		subject.banner.texture = subject.bannerTexture_doubleLine
		subject.banner.position.y = - 12
	else:
		subject.banner.texture = subject.bannerTexture_singleLine
		subject.banner.position.y = - 4

	subject.banner.offset_right = subject.bannerMargins[2]

	subject.subclassLabel.position.x = - 0.5 * textWidth

	subject.subclassLabel.show()
	subject.subclassLabel.set_end(subject.subclassLabel.position + Vector2(textWidth, 55))
	Util.callNextFrame(subject, "shrinkBanner", [textWidth])

static func calcPrice(subject: Receiver):
	if Expedition.enabled and Expedition.bridge != null:
		var data = Expedition.bridge.slot_data(subject.index)
		if not data.is_empty(): subject.pve_sync(data)
		return
	if not subject.item: return

	subject.wasOnSale = subject.onSale

	if subject.saleMode == Game.SaleMode.Free:
		subject.free = true
		subject.onSale = false
	else:
		subject.free = false
		var normalPrice_decoded = subject.item.getPrice()
		var salePrice_decoded = subject.item.getSalePrice()
		subject.normalPrice = Game.encode(normalPrice_decoded)
		subject.salePrice = Game.encode(salePrice_decoded)

		if subject.saleMode == Game.SaleMode.Roll:
			subject.onSale = salePrice_decoded < normalPrice_decoded and Game.shopSceneNode.rollSale(subject)
		elif subject.saleMode == Game.SaleMode.NoSale:
			subject.onSale = false
		else:
			subject.onSale = true

static func updatePrice(subject: Receiver):
	if Expedition.enabled and Expedition.bridge != null:
		subject.pve_sync(Expedition.bridge.slot_data(subject.index))
		return
	if subject.onSale:
		subject.price = subject.salePrice
		subject.salePriceLabel.text = str(Game.decode(subject.salePrice))
		if subject.wasOnSale:
			subject.saleAnimation.play("OnSale")
			subject.saleAnimation.advance(2)
			subject.saleAnimation.play("SaleFromSale")
		else:
			subject.saleAnimation.play("OnSale")

		Util.callDelayed(subject, "playSaleSound", 0.65)

	else:
		if subject.free:
			subject.normalPrice = Game.encode(0)

		subject.price = subject.normalPrice

		if subject.wasOnSale:
			subject.saleAnimation.play("RemoveSale")

	subject.priceLabel.text = str(Game.decode(subject.normalPrice))

	subject.checkMoney()

static func checkMoney(subject: Receiver, _goldChange):
	if subject.price == 0:
		return
	if subject.item and not subject.bought:
		if Game.getGold() >= Game.decode(subject.price):
			subject.item.affordable = true
			subject.item.enablePicking()
			Game.setItemEditMode(subject.item)
			subject.priceLabel.modulate = Color.WHITE
			subject.salePriceLabel.modulate = Color.WHITE
		else:
			subject.item.affordable = false
			subject.item.disablePicking()
			subject.priceLabel.modulate = subject.tooPoorColor
			subject.salePriceLabel.modulate = subject.tooPoorColor

static func buy(subject: Receiver):
	if not is_instance_valid(subject.item) or not bool(subject.item.get_meta("pve_purchase_committed", false)): return
	if subject.bought: return
	subject.bought = true
	subject.reserved = false
	Util.tryDisconnect(subject.item, "dropped", subject, "dropped")
	subject.animation.play("Bought")
	if subject.onSale: subject.saleAnimation.play("RemoveSale")
	subject.onSale = false
	subject.free = false
	subject.uniqueParticles.emitting = false
	Sound.playSound(Game.shopSceneNode.rerollSound, 4, 0.8)
	Game.shopSceneNode.onItemBought(subject.item, subject)
	return

static func reset(subject: Receiver):
	if subject.reserved: return

	if subject.item != null and not subject.bought:
		subject.item.discard()
	subject.bought = false
	subject.item = null
	subject.saleAnimation.play("RESET")
	subject.saleAnimation.advance(1)
	subject.subclassAnimation.play("RESET")
	subject.subclassAnimation.advance(1)
	subject.subclassLabel.text = ""
	subject.subclassLabel.size.x = 0
	subject.animation.play("RESET")
	subject.animation.advance(1)
	subject.onSale = false
	subject.free = false
	subject.saleMode = Game.SaleMode.Roll
	subject.uniqueParticles.emitting = false

static func throwOut(subject: Receiver):
	if subject.canThrowOut():
		if subject.subclassLabel.visible:
			subject.subclassAnimation.play("Hide")

		subject.item.disablePicking()
		ItemBook.onOwnableItemRemoved(subject.item)

		var dur = subject.throwOutDur * Util.rng.randf_range(0.8, 1.2) + 0.25

		subject.item.z_index += 2
		var tween = subject.create_tween().set_parallel(true)
		Util.moveParable(tween, subject.item, Util.rng.randf_range(700, 900),
			Util.rng.randf_range( - 400, - 100), dur)

		tween.tween_property(subject.item, "rotation", Util.rng.randf_range( - 2 * PI, 2 * PI), dur)
		tween.tween_callback(Callable(subject.item, "discard")).set_delay(dur)

static func setReserved(subject: Receiver, state):
	if Expedition.enabled and Expedition.bridge != null:
		if Expedition.syncing: return
		if not subject.canChangeReserveState(): return
		var result = Expedition.bridge.set_lock(subject, bool(state))
		if result.ok: subject.pve_sync(Expedition.bridge.slot_data(subject.index))
		return
	if state == subject.reserved: return
	if not subject.canChangeReserveState(): return

	subject.reserved = state

	Game.cancelSwitch()

	if subject.animation.current_animation != "":
		subject.animation.advance(1)

	if subject.reserved:
		subject.animation.play("Reserve")
		subject.reserveAnimation.play("Reserve")

		subject.reserveHint.translationKey = "HINT_Unreserve"
		subject.reserveHint.updateText()
		Sound.playSound(subject.reserveSound)
	else:
		subject.animation.play("Unreserve")
		subject.reserveAnimation.play("Unreserve")

		subject.reserveHint.translationKey = "HINT_Reserve"
		subject.reserveHint.updateText()
		Sound.playSound(subject.reserveSound, 0, 0.8)

static func pve_sync(subject: Receiver, data: Dictionary):
	if data.is_empty(): return
	subject.priceLabel.add_theme_font_size_override("font_size", 40)
	subject.wasOnSale = subject.onSale
	subject.free = false
	var base = int(data.get("base_price", int(data.get("price", 0))))
	if subject.item != null: base = int(Expedition.flow.placement.definition(str(data.definition_id)).get("base_price", base))
	subject.onSale = bool(data.get("discounted", false))
	subject.normalPrice = Game.encode(base if subject.onSale else int(data.get("price", base)))
	subject.salePrice = Game.encode(int(data.get("price", base)))
	subject.reserved = bool(data.get("locked", false))
	subject.bought = bool(data.get("sold", false))
	subject.price = subject.salePrice
	subject.priceLabel.text = str(base if subject.onSale else int(data.get("price", base)))
	subject.salePriceLabel.text = str(int(data.get("price", base)))
	if subject.onSale:
		subject.saleAnimation.play("OnSale")
		subject.saleAnimation.advance(2)
	elif subject.wasOnSale: subject.saleAnimation.play("RemoveSale")
	subject.reserveAnimation.play("Reserve" if subject.reserved else "Unreserve")
	subject.reserveAnimation.advance(2)
	subject.checkMoney()

static func pve_reset(subject: Receiver):
	subject.reserved = false
	if is_instance_valid(subject.item) and str(subject.item.get_meta("pve_uid", "")).is_empty() and not subject.item.dragged:
		subject.item.discard()
	subject.item = null
	subject.bought = false
	subject.onSale = false
	subject.free = false
	subject.price = 0
	subject.priceLabel.self_modulate = Color.TRANSPARENT
	subject.saleAnimation.play("RESET")
	subject.saleAnimation.advance(1)
	subject.subclassAnimation.play("RESET")
	subject.subclassAnimation.advance(1)
	subject.animation.play("RESET")
	subject.animation.advance(1)
	subject.uniqueParticles.emitting = false

static func updateLocale(subject: Receiver):
	if subject.item != null:
		if subject.item.descriptor.startsSubclass != "":
			subject.setBannerText(Game.getTranslatedSubclassName(subject.item.descriptor.startsSubclass))
		if subject.item.hasType(Item.Type.Skill):
			subject.setBannerText(subject.item.getTranslatedName())

static func canChangeReserveState(subject: Receiver) -> bool:
	if subject.item == null: return false
	if subject.bought: return false

	if Game.draggedItem != null and Util.time > Game.lastItemDropTime: return false

	return true
