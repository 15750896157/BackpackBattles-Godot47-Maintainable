extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Shopkeeper.gd")

static func _ready(subject: Receiver) -> void :
	Game.connect("shop_opened", Callable(subject, "onShopOpened"))
	Game.connect("item_bought", Callable(subject, "onBuy"))
	Game.connect("item_sold", Callable(subject, "onSell"))
	Game.connect("return_to_title", Callable(subject, "onReturnToTitle"))
	Game.connect("returned_to_title", Callable(subject, "onReturnedToTitle"))
	Game.connect("crafting_ready", Callable(subject, "onCraftingReady"))
	Game.connect("item_crafted", Callable(subject, "onCraft"))
	Game.connect("combat_start_pressed", Callable(subject, "onStartPressed"))
	subject.add_to_group("Localized")
	subject.updateLocale()

	if Util.isChristmas():
		var christmasHead = Sprite2D.new()
		christmasHead.texture = load("res://Assets/Shop/Shopkeeper/Shopkeeper_Head_Christmas.png")
		subject.head.add_child(christmasHead)
		christmasHead.position = Vector2(12, - 70)
		subject.head.self_modulate.a = 0

static func onShopOpened(subject: Receiver):
	Game.speechBubble.z_index = 33

	subject.showCraftFlavorText = Util.flip(0.15)

	if Game.runWasJustContinued:
		Game.speechBubble.say(Util.tr_nbs("CONTINUE" + subject.randNum(5)))
	else:
		if Game.curRound == 1:
			if Game.getNumStartedRuns() == 1:
				subject.tutorial()
			else:
				if Game.runsStartedThisSession == 1:
					subject.hello()
				else:
					subject.helloAgain()

		elif Game.curRound == Game.SUBCLASS_ROUND:
			if ( not Game.isTutorialDone(Game.TutorialSteps.Subclass)):
				Game.speechBubble.say(Util.tr_nbs("TUTORIAL_Subclass"), 10)
				Game.setTutorialDone(Game.TutorialSteps.Subclass)

			else:
				Game.speechBubble.say(Util.tr_nbs("SUBCLASS" + subject.randNum(3)), 10)

		elif (Game.curRound == Game.SKILL_ROUND1 or
					Game.curRound == Game.SKILL_ROUND2):

			if not Game.isTutorialDone(Game.TutorialSteps.Skill):
				Game.speechBubble.say(Util.tr_nbs("TUTORIAL_Skill"), 10)
				Game.setTutorialDone(Game.TutorialSteps.Skill)
			else:
				Game.speechBubble.say(Util.tr_nbs("SKILL" + subject.randNum(6)), 12)

		elif Game.shopSceneNode.rolledUnique:
			var itemName = Game.shopSceneNode.rolledUnique.getTranslatedName(true)
			Game.speechBubble.say(Util.tr_nbs("UNIQUE_ITEM" + subject.randNum(2)
				).replace("$item", itemName), 8)

		elif Game.numTimesOutOfStamina >= 4 and Game.PLAYER.getTotalStaminaUsage() >= 2:
			Game.speechBubble.say(Util.tr_nbs("OUTOFSTAMINA" + subject.randNum(3)))

		else:

			if (Game.itemsAreFusing and
				not Game.isTutorialDone(Game.TutorialSteps.Lock) and
				Game.getNumCraftedItems() % 4 == 0):

				pass
			else:
				var t = Game.getNextTutorialText()

				if t != null:
					Game.speechBubble.say(t[0], 10, t[1])

				else:
					if Game.curRound == Game.MAX_ROUNDS:
						Game.speechBubble.say(Util.tr_nbs("LASTROUND" + subject.randNum(3)))

					elif Game.justStartedSurvivalMode:
						Game.speechBubble.say(Util.tr_nbs("SURVIVAL" + subject.randNum(4)))

					else:
						match Game.getLastRoundResult():
							Game.RoundResult.Win:
								if ( not Game.isTutorialDone(Game.TutorialSteps.Wins) and
									Game.wins == 1):
									Game.speechBubble.say(Util.tr_nbs("TUTORIAL_Wins"), 10)
									Game.setTutorialDone(Game.TutorialSteps.Wins)
								else:
									subject.onWin()
							Game.RoundResult.Loss:
								if ( not Game.isTutorialDone(Game.TutorialSteps.Tries) and
									Game.tries == 4):
									Game.speechBubble.say(Util.tr_nbs("TUTORIAL_Tries"), 10)
									Game.setTutorialDone(Game.TutorialSteps.Tries)
								else:
									subject.onLoss()

static func onBuy_tutorial(subject: Receiver, item, onSale, sequenceNum):
	if Game.speechBubble.getSequenceNumber() == sequenceNum:
		Game.speechBubble.shutUp()

	if Game.usingController:
		var text = Util.tr_nbs("TUTORIAL_ROTATE_CONTROLLER")
		var icon1 = ControllerIcons.getIconFromAction("rotate_left_button_controller")
		var icon2 = ControllerIcons.getIconFromAction("rotate_right_button_controller")
		text = text.format({
			"button1": Util.imageToBbcode(icon1, 40),
			"button2": Util.imageToBbcode(icon2, 40)})
		Game.speechBubble.say(text, 5, Game.TutorialSteps.Rotate)
	else:
		Game.speechBubble.say(Util.tr_nbs("TUTORIAL_ROTATE"), 5,
			Game.TutorialSteps.Rotate)

static func onLoss(subject: Receiver):
	if Game.getTries() == 1:
		Game.speechBubble.say(Util.tr_nbs("LASTTRY" + subject.randNum(3)))

	else:
		var n: String
		if Game.getTries() > 1:
			n = subject.randNum(14)
		else:
			n = subject.randNum(13)

		var t = Util.tr_nbs("LOST" + n)

		if n == "14":
			t = t.replace("$tries", str(Game.getTries()))

		Game.speechBubble.say(t)

static func onBuy(subject: Receiver, item, onSale):
	if (item.isSubclassItem() and
		item.isGateItem() and
		item.ownerType == Item.Owner.PlayerStorageBox):

			Game.speechBubble.shutUp()
			Game.speechBubble.say(Util.tr_nbs("STORAGE_HINT").replace("$item",
				item.getTranslatedName(true)), 6, true)
			return

	if Game.speechBubble.isSpeaking(): return

	if ( not Game.isTutorialDone(Game.TutorialSteps.Stars) and
		item.getNumAffectedCells() > 0):
			var t = Util.tr_nbs("TUTORIAL_Stars")
			t = t.replace("$star", Util.getIcon("affected"))
			Game.speechBubble.say(t, 10)
			Game.setTutorialDone(Game.TutorialSteps.Stars)
	else:
		var rng = Util.rng.randf()
		if rng < 0.15:
			var flavor = item.getFlavorText()
			if flavor != "" and rng < 0.07:
				Game.speechBubble.say(flavor)
			elif onSale:
				Game.speechBubble.say(Util.tr_nbs("BUY_SALE" + subject.randNum(7)).replace("$item", item.getTranslatedName(true)))
			elif item.getRarity() >= Item.Rarity.Legendary:
				Game.speechBubble.say(Util.tr_nbs("BUY_RARE" + subject.randNum(6)).replace("$item", item.getTranslatedName(true)))
			else:
				Game.speechBubble.say(Util.tr_nbs("BUY_NORMAL" + subject.randNum(12)).replace("$item", item.getTranslatedName(true)))

static func onCraft(subject: Receiver, _itemDescriptor):

	if ( not Game.isTutorialDone(Game.TutorialSteps.Lock) and
		Game.getNumCraftedItems() % 4 == 1 and
		not Game.speechBubble.isGivingTutorial()):
			subject.giveLockHint()
	elif not Game.speechBubble.isGivingTutorial() and subject.showCraftFlavorText:
		var flavor = _itemDescriptor.getFlavorText()
		if flavor != "":
			Game.speechBubble.say(flavor)
			subject.showCraftFlavorText = false

static func giveLockHint(subject: Receiver):
	Game.speechBubble.shutUp()
	if Game.usingController:
		var text = Util.tr_nbs("TUTORIAL_Lock_CONTROLLER")
		text = text.format({"button": Util.getControllerIconBbcode("lock_combining_controller")})
		Game.speechBubble.say(text, 8, Game.TutorialSteps.Lock)
	else:
		Game.speechBubble.say(Util.tr_nbs("TUTORIAL_Lock"), 8, Game.TutorialSteps.Lock)

static func onDecorationDestructed(subject: Receiver):
	if Game.speechBubble.isSpeaking(): return

	if subject.reaction == null or not subject.reaction.is_inside_tree():
		subject.reaction = ObjectPool.instantiate(subject.destructReactionScene)
		subject.add_child(subject.reaction)
		subject.reaction.text = subject.reactionFormat.format({
			"level": Util.rng.randi_range(0, 3) * 10,
			"exclamation": Util.pickRandomElement(subject.exclamations)
		})
		subject.reaction.get_node("AnimationPlayer").play("React")
