extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Tooltips/ItemTooltip.gd")

static func preset(subject: Receiver):
	subject.vboxcontainer = subject.get_node("VBoxContainer")
	subject.marginContainer = subject.get_node("VBoxContainer/MarginContainer")
	subject.descrLabel = subject.get_node("VBoxContainer/MarginContainer/Description")
	subject.animation = subject.get_node("AnimationPlayer")
	subject.propertyContainer = subject.get_node("VBoxContainer/PropertyContainer")
	subject.hboxContainer = subject.get_node("VBoxContainer/HBoxContainer")
	subject.rarityLabel = subject.get_node("VBoxContainer/HBoxContainer/Rarity")
	subject.typeLabel = subject.get_node("VBoxContainer/HBoxContainer/HBoxContainer/Type")
	subject.extraTypesLabel = subject.get_node("VBoxContainer/ExtraTypes")
	subject.typesContainer = subject.get_node("VBoxContainer/HBoxContainer/HBoxContainer")
	subject.divider1 = subject.get_node("VBoxContainer/Divider1")
	subject.divider2 = subject.get_node("VBoxContainer/Divider2")
	subject.spacer2 = subject.get_node("VBoxContainer/HBoxContainer/Spacer2")

static func setItem(subject: Receiver, _item):

	subject.set_physics_process(false)
	subject.spacer2.custom_minimum_size.x = 15
	subject.vboxcontainer.size.x = 470
	subject.divider2.texture = subject.divider1.texture
	subject.divider2.material = subject.divider1.material

	var lastTooltipDuration = Game.lastHideItemTooltipFrame - Game.lastShowItemTooltipFrame
	var timeSinceLastHide = Util.getFrameCounter_process() - Game.lastHideItemTooltipFrame

	subject.item = _item

	Game.lastShowItemTooltipFrame = - 1

	if _item.spotlight or subject.item.ownerType == subject.item.Owner.Shop:
		Game.lastBagTooltipWasDelayed = false
		subject.setVisible()
	else:
		if lastTooltipDuration > 5 or Game.lastBagTooltipWasDelayed or timeSinceLastHide > 10:
			if _item.isBag() and _item.placed and ( not Game.lastTooltipWasBag or timeSinceLastHide > 10):

				Game.lastBagTooltipWasDelayed = true

				subject.setVisibleIn(3)
			else:
				Game.lastBagTooltipWasDelayed = false
				subject.setVisible()
		else:
			if _item.isBag() and _item.placed:
				Game.lastBagTooltipWasDelayed = true
			else:
				Game.lastBagTooltipWasDelayed = false

			subject.setVisibleIn(6)

	Game.lastTooltipWasBag = _item.isBag() and _item.placed

	subject.nameLabel.text = ""

	subject.nameLabel.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)

	if Settings.getVal(Settings.Setting.text_effects):
		if subject.item.getTextEffect() != subject.TextEffect.None:
			subject.nameLabel.append_text(str("[item s=", subject.item.getTextEffect(), "]"))

	subject.nameLabel.add_text(subject.item.getTranslatedName())

	subject.updateTooltip(true)
	if Expedition.enabled and subject.item.has_meta("pve_definition_id"):
		subject._set_pve_identity()
		Util.localizeFonts(subject)
		preload("res://PvE/Art/TooltipSkin.gd").apply(subject)
		subject.updateSize()
		subject.call_deferred("fixSpillingTypes")
		ItemBook.pausePrepare()
		return

	if subject.item.descriptor.isNeutral():
		var classIcon = ObjectPool.instantiate(subject.classIconScene)
		subject.toReturn.push_back(classIcon)
		classIcon.setClass( - 1)

		subject.hboxContainer.add_child(classIcon)
		subject.hboxContainer.move_child(classIcon, 1)
	else:
		var pos = 1
		for classI in Game.getNumClasses():
			if subject.item.descriptor.isAvailableFor(classI):
				var classIcon = ObjectPool.instantiate(subject.classIconScene)
				subject.toReturn.push_back(classIcon)
				classIcon.setClass(classI)

				subject.hboxContainer.add_child(classIcon)
				subject.hboxContainer.move_child(classIcon, pos)
				pos += 1

	subject.extraTypesLabel.text = ""
	subject.extraTypesLabel.hide()

	subject.rarityLabel.text = subject.item.getTranslatedRarity()
	subject.rarityLabel.set("theme_override_colors/font_color", Game.rarityColors[subject.item.getRarity()].lightened(0.6))

	var types = subject.item.getTypes()
	var numStaticTypes = subject.item.getNumStaticTypes()
	var numDynamicTypes = types.size() - numStaticTypes
	subject.typeLabel.show()

	if Game.USE_ICONS:
		for i in range(types.size() - 1, - 1, - 1):

			var iconName = subject.item.descriptor.getTypeName(types[i]).to_lower()

			if iconName in Util.iconTextures:
				var typeIcon = ObjectPool.instantiate(subject.typeIconScene)
				subject.toReturn.push_back(typeIcon)
				typeIcon.texture = Util.iconTextures[iconName]
				subject.typesContainer.add_child(typeIcon)
				subject.typesContainer.move_child(typeIcon, 0)
				var ani = typeIcon.get_node("AnimationPlayer")
				ani.stop()
				if i < numDynamicTypes:
					ani.play("Dynamic")
				else:

					ani.play("RESET")

			else:
				if i == numDynamicTypes:
					subject.typeLabel.text = subject.item.getTranslatedTypeName(types[i])
				else:
					subject.extraTypesLabel.show()
					if subject.extraTypesLabel.text != "":
						subject.extraTypesLabel.text += "  "
					subject.extraTypesLabel.text += subject.item.getTranslatedTypeName(types[i])

		if subject.item.descriptor.isTreasure():
			var typeIcon = ObjectPool.instantiate(subject.typeIconScene)
			typeIcon.texture = Util.iconTextures["treasure"]
			subject.typesContainer.add_child(typeIcon)
			subject.typesContainer.move_child(typeIcon, 0)
			subject.toReturn.push_back(typeIcon)
	else:
		subject.typeLabel.text = subject.item.getTranslatedTypeName(types[0])

		if types.size() > 1:
			subject.extraTypesLabel.show()
			subject.extraTypesLabel.text = ""
			for i in range(1, types.size()):
				if i != 1:
					subject.extraTypesLabel.text += "  "
				subject.extraTypesLabel.text += subject.item.getTranslatedTypeName(types[i])

	subject.addReferenceExplanations(subject.references)

	var bags = subject.item.getTouchedBagsCounted()
	if bags != null:
		for bag in bags:
			var number = bags[bag]
			var bagEffect = bag.getBagEffect(number)
			if bagEffect != "" and bag.canApplyEffect(subject.item):
				var replacement = bag.getTranslatedName()
				if number > 1:
						replacement += " x" + str(number)
				bagEffect = bagEffect.replace("$bag", subject.highlight(replacement))
				subject.addSubDescription(subject.bagEffectIcon + bagEffect, true)

	subject.updateSize()

	Util.localizeFonts(subject)

	subject.call_deferred("fixSpillingTypes")
	subject.call_deferred("removeStackDescriptions")

	ItemBook.pausePrepare()

static func _set_pve_identity(subject: Receiver):
	var definition = Expedition.flow.placement.definition(str(subject.item.get_meta("pve_definition_id")))
	var rarity = Expedition.db.get_row("rarities", str(definition.get("rarity", "common")))
	subject.rarityLabel.text = Expedition.t(str(rarity.name_key))
	subject.rarityLabel.set("theme_override_colors/font_color", Game.rarityColors[subject.item.getRarity()].lightened(0.6))
	var class_icon = ObjectPool.instantiate(subject.classIconScene)
	subject.toReturn.push_back(class_icon)
	var owner_pool = str(definition.get("owner_pool", "public"))
	class_icon.setClass(Game.Classes_Full.Berserker if owner_pool == "armorer" else Game.Classes_Full.Reaper if owner_pool == "alchemist" else -1)
	subject.hboxContainer.add_child(class_icon)
	subject.hboxContainer.move_child(class_icon, 1)
	var tags = PackedStringArray()
	for tag_id in Expedition.db.list_values(definition.get("tags", "")):
		var tag = Expedition.db.get_row("tags", str(tag_id))
		if tag.is_empty(): continue
		var tag_name = Expedition.t(str(tag.name_key))
		tags.append(tag_name)
		subject.addSubDescription(subject.highlight(tag_name) + ": " + Expedition.t(str(tag.description_key)), false)
	subject.typeLabel.show()
	subject.typeLabel.text = " · ".join(tags) if not tags.is_empty() else Expedition.bilingual("背包", "Bag")
	subject.extraTypesLabel.text = ""
	subject.extraTypesLabel.hide()

static func updateTooltip(subject: Receiver, init: bool):
	subject.sizeChanged = false

	var description = subject.item.getDescription()
	if Expedition.enabled and subject.item.has_meta("pve_definition_id"):
		var definition = Expedition.flow.placement.definition(str(subject.item.get_meta("pve_definition_id")))
		if not definition.is_empty():
			if Expedition.has_method("item_description"):
				description = Expedition.call("item_description", str(definition.id))
			else:
				var rules = load("res://PvE/Rules/content/RuleText.gd").new(Expedition.db)
				description = rules.item(str(definition.id), "zh_CN" if TranslationServer.get_locale().begins_with("zh") else "en")
	description = description.replace("\\~", "\n")
	description = description.replace("\\n", "\n")
	description = description.replace(" \n", "\n")
	description = description.replace("\n ", "\n")

	if init:
		for keyword in subject.keywords:
			if Game.getNumStartedRuns() > 2 and keyword == "affected":
				continue

			var pos = description.find("$" + keyword)
			if pos != - 1 and Util.isNonLatinLetterOrNumber(description[pos + 1 + keyword.length()]):

				subject.references.push_back(keyword)
		subject.references = Util.filterDuplicates(subject.references)

	description = subject.replaceReferences(description)

	if description != "":
		description = subject.scolor_movePunctuation(description)
		subject.descrLabel.text = description

	else:
		subject.marginContainer.hide()
	if Expedition.enabled and subject.item.has_meta("pve_definition_id"):
		subject._update_pve_properties()
		preload("res://PvE/Art/TooltipSkin.gd").apply(subject)
		if not init and subject.sizeChanged: subject.forceUpdate()
		return

	if subject.item.isWeapon() and subject.item.canDamage():
		var damRange = subject.item.getDamageRange()

		subject.addProperty(subject.item.Stat.MaxDamage, Util.tra("TOOLTIP_Damage"),
			damRange, subject.item.isDamageModified(),
		str(snapped(subject.item.getDPS(), 0.1)), subject.item.isDPSModified())

	var staminaCost = subject.item.getStaminaCost()
	if subject.item.isWeapon():
		var staminaPS = subject.item.getStaminaPerSecond()

		subject.addProperty(subject.item.Stat.StaminaCost, Util.tra("TOOLTIP_StaminaCost"),
			str(snapped(staminaCost, 0.01)), subject.item.isStaminaModified(),
			str(snapped(staminaPS, 0.1)), subject.item.isStaminaPerSecondModified())

	var baseAccuracy = subject.item.getBaseAccuracy()
	if baseAccuracy != 0:
		var accuracy: String
		if Game.state == Game.State.Combat:
			accuracy = subject.item.getCombatDisplayAccuracy()
		else:
			accuracy = str(subject.item.getAccuracy())

		var accuracyStr = accuracy
		if Util.hasSpaceBeforePercent():
			accuracyStr += Util.nonBreakingSpace
		accuracyStr += "%"
		subject.addProperty(subject.item.Stat.Accuracy, Util.tra("TOOLTIP_Accuracy"),
			accuracyStr, subject.item.isAccuracyModified())

	if subject.item.isWeapon() and subject.item.canBeEmpowered():
		var cooldown = subject.item.getModifiedCooldown()
		if cooldown != 0:
			var secondsStr = Util.tra("FORMAT_Second")
			if Util.hasSpaceBeforeSeconds():
				secondsStr = Util.nonBreakingSpace + secondsStr
			subject.addProperty(subject.item.Stat.Cooldown, Util.tra("TOOLTIP_Cooldown"),
				str(snapped(cooldown, 0.01)) + secondsStr,
				subject.item.isCooldownModified())

	if subject.item.canDamage():
		var critChancePercent = subject.item.getCritChancePercent()
		if critChancePercent != 0:
			subject.addProperty(subject.item.Stat.CritChance, Util.tra("TOOLTIP_CritChance"),
				subject.item.getDisplayCritChance() + "%",
				subject.item.StatModified.Positive)

	if not init and subject.sizeChanged:
		subject.forceUpdate()

static func _update_pve_properties(subject: Receiver):
	var definition = Expedition.flow.placement.definition(str(subject.item.get_meta("pve_definition_id")))
	var stats: Dictionary = subject.item.get_meta("pve_preview", {})
	if stats.is_empty(): stats = Expedition.bridge.definition_stats(str(definition.id))
	var damage = float(stats.get("damage", stats.get("base_damage", 0.0)))
	var cooldown = float(stats.get("cooldown", definition.get("cooldown", 0.0)))
	var stamina = float(stats.get("stamina_cost", definition.get("stamina_cost", 0.0)))
	if damage > 0.0:
		subject.addProperty(Item.Stat.MaxDamage, Util.tra("TOOLTIP_Damage"), subject._pve_number(damage), Item.StatModified.No,
			subject._pve_number(damage / cooldown) if cooldown > 0.0 else null)
	if stamina > 0.0:
		subject.addProperty(Item.Stat.StaminaCost, Util.tra("TOOLTIP_StaminaCost"), subject._pve_number(stamina), Item.StatModified.No,
			subject._pve_number(stamina / cooldown) if cooldown > 0.0 else null)
	if cooldown > 0.0:
		subject.addProperty(Item.Stat.Cooldown, Util.tra("TOOLTIP_Cooldown"), subject._pve_number(cooldown) + Util.tra("FORMAT_Second"), Item.StatModified.No)
	var crit = float(stats.get("crit_chance", 0.0))
	if damage > 0.0 and crit > 0.0:
		subject.addProperty(Item.Stat.CritChance, Util.tra("TOOLTIP_CritChance"), subject._pve_number(crit * 100.0) + "%", Item.StatModified.No)

static func addReferenceExplanations(subject: Receiver, refs):
	for type in subject.item.getTypes():
		var typeDescr = subject.item.getTypeDescription(type)
		if typeDescr != "":
			var typeName = subject.item.getTranslatedTypeName(type)
			var text = subject.highlight(typeName)
			var cooldown = Util.wrapInColor_fixed(str(snapped(subject.item.getModifiedCooldown(), 0.01)),
				Util.statColors[subject.item.isCooldownModified()])

			typeDescr = typeDescr.format({
				"itemName": subject.highlight(subject.item.getTranslatedName()),
				"cd": cooldown
				})
			if TranslationServer.get_locale() == "fr":
				text += Util.nonBreakingSpace
			text += ": " + subject.replaceReferences(typeDescr)
			subject.addSubDescription(text, false)

	for reference in refs:
		var description = Util.tra(reference + "_DESCR")
		if description == "": continue

		var text = ""
		if reference in Util.icons:
			text += Util.getIcon(reference)
		text += subject.highlight(Util.tra(reference + "_NAME"))
		if TranslationServer.get_locale() == "fr":
			text += Util.nonBreakingSpace

		if reference == "rage":
			description = description.format({
				"delay": Game.PLAYER.AUTO_RAGE_DELAY,
				"duration": Game.PLAYER.AUTO_RAGE_DUR
			})

		text += ": " + subject.replaceReferences(description)
		subject.addSubDescription(text, true)

		subject.stackDescriptionNodes.push_back(subject.toReturn[ - 2])
		subject.stackDescriptionNodes.push_back(subject.toReturn[ - 1])

static func addSubDescription(subject: Receiver, text: String, darken: bool):
	var divider = ObjectPool.instantiate(subject.dividerScene)
	subject.toReturn.push_back(divider)
	divider.texture = subject.divider1.texture
	divider.material = subject.divider1.material
	subject.subDescriptionPosition.add_sibling(divider)
	subject.subDescriptionPosition = divider
	var descr = ObjectPool.instantiate(subject.descriptionScene)
	if darken:
		descr.modulate = Color(0.960784, 0.960784, 0.960784)
	else:
		descr.modulate = Color(1.1, 1.1, 1.1)

	subject.toReturn.push_back(descr)
	text = text.replace("\\~", "\n")
	text = subject.item.insertParameters(text)
	text = subject.scolor_movePunctuation(text)
	descr.text = subject.replaceReferences(text)
	subject.subDescriptionPosition.add_sibling(descr)
	subject.subDescriptionPosition = descr

static func addProperty(subject: Receiver, stat: int, _name, value, modified: int, perSecond, perSecondModified):

	var prop = subject.properties.get(stat, null)
	if prop == null:

		prop = ObjectPool.instantiate(subject.propertyScene)
		subject.toReturn.push_back(prop)
		subject.propertyContainer.add_child(prop)
		subject.properties[stat] = prop
		subject.sizeChanged = true

		var divider = ObjectPool.instantiate(subject.dividerScene)
		divider.texture = subject.divider1.texture
		divider.material = subject.divider1.material
		subject.propertyContainer.add_child(divider)
		subject.toReturn.push_back(divider)

	var icon = Util.weaponIcons[stat]
	prop.setTuple(_name, value, modified, icon)

	if perSecond:
		var perSecondStr = str("(", perSecond, "/", Util.tra("FORMAT_Second"), ")")
		prop.setPerSecond(perSecondStr, perSecondModified)

static func discard(subject: Receiver):
	Game.lastHideItemTooltipFrame = Util.getFrameCounter_process()
	if Game.lastShowItemTooltipFrame == - 1:
		Game.lastShowItemTooltipFrame = Game.lastHideItemTooltipFrame

	for node in subject.stackDescriptionNodes:
		node.show()

	for node in subject.toReturn:
		ObjectPool.returnInstance(node)

	subject.toReturn.clear()
	subject.properties.clear()
	subject.references.clear()
	subject.stackDescriptionNodes.clear()
	Util.tryDisconnect(subject.get_tree(), "process_frame", subject, "updateSize")

	subject.nameLabel.text = ""
	subject.nameLabel.size.y = 0
	subject.descrLabel.text = ""
	subject.descrLabel.size.y = 0
	subject.marginContainer.show()

	ObjectPool.returnInstance(subject)

static func scolor_movePunctuation(subject: Receiver, text):
	var chars = subject.punctuationCharacters.get(TranslationServer.get_locale(), subject.latinPunctuationCharacters)
	for i in 2:
		for character in chars:
			text = text.replace("[/sc]" + character, character + "[/sc]")
	return text
