extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForSeasonClassRank:
	const Receiver = preload("res://Interface/SeasonClassRank.gd")

	static func setLeague(subject: Receiver, classI: int, leagueExact: float):
		subject.icon.texture = Game.classIcons[classI]
		subject.rankLabel.text = str(int(fmod(leagueExact, 1.0) * 100))
		var league = int(leagueExact)
		subject.emblem.setLeague(league)

class ForShopRarityChart:
	const Receiver = preload("res://Interface/ShopRarityChart.gd")

	static func onShopOpened(subject: Receiver):
		var odds = Game.shopSceneNode.getRarityOddsForCurRound()
		var normalizedOdds = odds.duplicate()
		var maxOdd = odds.max()
		for i in normalizedOdds.size():
			normalizedOdds[i] /= maxOdd

		var tween = subject.create_tween().set_parallel()

		for rarity in range(5):
			var bar = subject.bars[rarity]
			if odds[rarity] == 0:
				pass

			else:
				bar.self_modulate.a = 1

				var ySize = 5 + 46 * normalizedOdds[rarity]

				tween.tween_property(bar, "scale:y", 1.0, subject.ANI_DUR)
				tween.tween_property(bar, "custom_minimum_size:y", ySize, subject.ANI_DUR)

class ForSnowGlobe:
	const Receiver = preload("res://Interface/SnowGlobe.gd")

	static func _ready(subject: Receiver):
		subject.get_node("Button").connect("pressed", Callable(subject, "onButtonPressed"))
		Game.connect("pre_shop_opened_from_title", Callable(subject, "onEnteringShop"))
		Game.connect("return_to_title", Callable(subject, "onShopToTitle"))

class ForStaminabar:
	const Receiver = preload("res://Interface/Staminabar.gd")

	static func _ready(subject: Receiver) -> void :
		subject.set_process(false)
		Game.connect("switching_to_combat", Callable(subject, "onEnteringCombat"))
		Game.connect("combat_scene_left", Callable(subject, "onCombatLeft"))
		subject.resetBar()
		subject.call_deferred("ready_deferred")

	static func _process(subject: Receiver, _delta: float) -> void :
		var relStamina = subject.character.curStamina / subject.character.getMaxStamina()
		relStamina *= 1.02
		subject.staminaMat.set_shader_parameter("lastDamagePercentage", relStamina)
		subject.displayRelStamina = lerp(subject.displayRelStamina, relStamina, _delta * 2)
		subject.staminaMat.set_shader_parameter("healthPercentage", subject.displayRelStamina)

		subject.updateNumber()

class ForStaminaGainCounter:
	const Receiver = preload("res://Interface/StaminaGainCounter.gd")

	static func _ready(subject: Receiver) -> void :
		Game.PLAYER.connect("class_changed", Callable(subject, "updateText"))
		Game.PLAYER.connect("stamina_regen_changed_ui", Callable(subject, "updateText"))
		subject.updateText()

class ForStaminaUseCounter:
	const Receiver = preload("res://Interface/StaminaUseCounter.gd")

	static func updateLocale(subject: Receiver):
		subject.updateQueued = false
		var previousState = subject.icon.frame
		var totalStaminaUse = Game.PLAYER.getTotalStaminaUsage()
		var key = "STAMINA_"
		if totalStaminaUse < 0.5:
			subject.icon.frame = 0
			key += "VeryLow"
		elif totalStaminaUse < 1.2:
			subject.icon.frame = 1
			key += "Low"
		elif totalStaminaUse < 1.5:
			subject.icon.frame = 2
			key += "Medium"
		elif totalStaminaUse < 2.0:
			subject.icon.frame = 3
			key += "High"
		else:
			subject.icon.frame = 4
			key += "VeryHigh"

		subject.setTranslationKey(key)

		if previousState != subject.icon.frame:
			if subject.icon.frame == 4:

				subject.animation.play("VeryHighStart")
				subject.animation.queue("VeryHighUsage")
			else:
				subject.animation.play("RESET")

			subject.set("theme_override_colors/font_color", subject.colors[subject.icon.frame])

		subject.tooltipArea.params = {
			"staminaGain": Util.wrapInColor("1", Util.paramColor),
			"staminaUsage": Util.wrapInColor(str(snapped(totalStaminaUse, 0.1)), Util.paramColor)
		}

class ForSwitchModeUI:
	const Receiver = preload("res://Interface/SwitchModeUI.gd")

	static func startGame(subject: Receiver):
		CustomRules.setSwitchMode(CustomRules.SwitchModeState.Ranked)
		Game.startFreshRun(Game.Mode.Unranked)
		Game.titleScreen.clearItems()

		subject.close()
		subject.emit_signal("close_requested", false)
