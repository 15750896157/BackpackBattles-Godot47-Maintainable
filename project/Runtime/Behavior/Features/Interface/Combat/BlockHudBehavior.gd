extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Combat/BlockHud.gd")

static func _ready(subject: Receiver) -> void :
	subject.sprite.scale = Vector2.ZERO
	subject.label.hide()
	subject.tooltip = subject.tooltipScene.instantiate()
	Game.UINode.add_child(subject.tooltip)
	Game.connect("switch_to_shop", Callable(subject, "onLeaveCombat"))
	Game.connect("return_to_title", Callable(subject, "onLeaveCombat"))
	subject.prevValue = 0
	for key in ["font_color", "font_outline_color"]:
		subject.pve_label_defaults[key] = {"override": subject.label.has_theme_color_override(key), "value": subject.label.get_theme_color(key)}
	subject.pve_label_defaults["outline_size"] = {"override": subject.label.has_theme_constant_override("outline_size"), "value": subject.label.get_theme_constant("outline_size")}
	subject.updateLocale()
	subject.add_to_group("Localized")
	subject.add_to_group("PvEBuffHUD")
	if Expedition.enabled and Expedition.preferences != null:
		subject.pve_update_accessibility(bool(Expedition.preferences.values.get("high_contrast", false)))
	if Expedition.enabled and not Expedition.initialized:
		subject.call_deferred("_pve_update_locale_when_ready")

static func _pve_update_locale_when_ready(subject: Receiver):
	while not Expedition.initialized:
		await subject.get_tree().process_frame
	subject.updateLocale()
	if Expedition.preferences != null: subject.pve_update_accessibility(bool(Expedition.preferences.values.get("high_contrast", false)))

static func pve_update_accessibility(subject: Receiver, enabled: bool):
	subject.pve_high_contrast = enabled
	for key in ["font_color", "font_outline_color"]:
		if enabled:
			subject.label.add_theme_color_override(key, Color.WHITE if key == "font_color" else Color.BLACK)
		elif subject.pve_label_defaults[key]["override"]:
			subject.label.add_theme_color_override(key, subject.pve_label_defaults[key].value)
		else:
			subject.label.remove_theme_color_override(key)
	if enabled: subject.label.add_theme_constant_override("outline_size", 6)
	elif subject.pve_label_defaults.outline_size["override"]: subject.label.add_theme_constant_override("outline_size", subject.pve_label_defaults.outline_size.value)
	else: subject.label.remove_theme_constant_override("outline_size")
	subject.queue_redraw()

static func _draw(subject: Receiver):
	if subject.pve_high_contrast and subject.prevValue != null and subject.prevValue > 0:
		subject.draw_circle(subject.sprite.position, 38.0, Color(0, 0, 0, 0.92))
		subject.draw_arc(subject.sprite.position, 38.0, 0, TAU, 48, Color.WHITE, 2.0, true)

static func updateLocale(subject: Receiver):
	if Expedition.enabled and Expedition.db != null:
		var rules = load("res://PvE/Rules/content/RuleText.gd").new(Expedition.db)
		var language = "zh_CN" if TranslationServer.get_locale().begins_with("zh") else "en"
		var mapping = {"poison": "poison", "regen": "regeneration", "regeneration": "regeneration", "heat": "burn", "cold": "slow", "lucky": "haste", "vampirism": "lifesteal", "blind": "vulnerable", "empower": "fortified"}
		var status = str(mapping.get(subject.keyword.to_lower(), ""))
		if not status.is_empty():
			var description = rules.status(status, language)
			if Expedition.flow != null and Expedition.flow.screen_state == "COMBAT_RUNNING" and int(subject.pve_timeline_status.get("stacks", 0)) > 0:
				var chinese = language.begins_with("zh")
				description += ("\n当前层数：%d / %d" if chinese else "\nCurrent stacks: %d / %d") % [int(subject.pve_timeline_status.stacks), int(subject.pve_timeline_status.get("cap", 0))]
				if status in ["poison", "burn", "regeneration"] and subject.pve_timeline_status.has("next_tick"):
					description += ("\n距下次跳动：%.2f 秒" if chinese else "\nNext tick in: %.2f seconds") % float(subject.pve_timeline_status.next_tick)
				if float(subject.pve_timeline_status.get("remaining_duration", -1)) >= 0:
					description += ("\n剩余持续：%.2f 秒" if chinese else "\nRemaining duration: %.2f seconds") % float(subject.pve_timeline_status.remaining_duration)
			subject.tooltip.setParams(rules.term("statuses", status, language), description)
			subject.set_meta("pve_status_id", status)
			return
		if subject.keyword.to_lower() == "block":
			for term in rules.dictionary(language):
				if term.id == "armor": subject.tooltip.setParams(term.term, term.definition); return
	subject.tooltip.setParams(Util.tra(subject.keyword + "_NAME"), Util.tra(subject.keyword + "_DESCR"))

static func calcScale(subject: Receiver, value) -> float:
	if value > subject.scaleThreshold:
		value = subject.scaleThreshold + pow((value - subject.scaleThreshold), 0.65)

	var s = 0.5 + sqrt(value / 100.0)

	return s

static func updateHud(subject: Receiver, value):
	if value == subject.prevValue:
		return

	if value > subject.prevValue:
		subject.animation.play("Increase")
	else:
		subject.animation.play("Decrease")

	subject.tween.stop_all()
	subject.tween.remove_all()
	var targetScale
	if value == 0:
		subject.label.hide()
		targetScale = Vector2.ZERO
	else:
		subject.label.show()
		targetScale = subject.baseScale * subject.calcScale(value)
		subject.label.text = str(value)

	subject.tween.interpolate_property(subject.sprite, "scale", null, targetScale, 0.3)
	subject.tween.start()

	subject.prevValue = value
	if subject.pve_high_contrast: subject.queue_redraw()

static func onHover(subject: Receiver):
	if subject.label.visible:
		if Expedition.enabled: subject.updateLocale()
		Game.onHoverInteractable(subject)
		subject.tooltip.forceUpdatePosition(subject.global_position, Vector2(100, 0))
