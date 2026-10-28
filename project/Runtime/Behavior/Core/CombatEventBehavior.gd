extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/CombatEvent.gd")

static func asText(subject: Receiver) -> String:
	var amount = subject.getParam("amount", 0)

	var typeStr = Game.eventTypeKeys[subject.type]
	var key = "LOG_"
	if "amount" in subject.params:
		subject.formatParams["amount"] = abs(amount)

		if subject.type == Game.EventType.DamIncrease or subject.type == Game.EventType.DamReduction:
			key += typeStr
			if "type" in subject.params:
				key += "_TYPED"
				subject.formatParams["type"] = Util.getIcon(DamageSource.damTypeNames[subject.params["type"]])
			if "duration" in subject.params:
				key += "_TEMP"
			if subject.params["isPercent"]:
				subject.formatParams["amount"] = str(subject.formatParams["amount"]) + "%"

		elif "timeout" in subject.params:
			key += "BuffTimeout"
			subject.formatParams["buff"] = Util.getIcon(Game.typeToKeyword(subject.type))
		else:
			if Game.isBuff(subject.type):
				subject.formatParams["buff"] = Util.getIcon(Game.typeToKeyword(subject.type))
			elif Game.isDebuff(subject.type):
				subject.formatParams["debuff"] = Util.getIcon(Game.typeToKeyword(subject.type))

			if subject.getParam("used", false):
				key += "USE_BUFF"

			elif subject.getParam("resisted", false):
				if Game.isBuff(subject.type):
					key += "NULLIFY_BUFF"
				else:
					if subject.getParam("reflected", false):
						key += "REFLECT_RESIST"
					else:
						key += "RESIST_DEBUFF"

			elif subject.getParam("protected", false):
				if Game.isBuff(subject.type):
					key += "PROTECT_BUFF"
				else:
					key += "PROTECT_DEBUFF"
			else:
				var reflect = subject.getParam("reflected", false)
				if reflect:
					key += "REFLECT_"
				elif amount < 0:
					key += "LOSE_"
				else:
					key += "GAIN_"

				if Game.isBuff(subject.type):
					key += "BUFF"
					if amount < 0:
						if subject.getMainActor() == subject.target:
							key += "_SELF"
					else:
						if "duration" in subject.params:
							key += "_TEMP"
						if subject.getMainActor() != subject.target:

							key += "_OPPONENT"

				elif Game.isDebuff(subject.type):
					key += "DEBUFF"
					if not reflect and amount > 0 and subject.getMainActor() == subject.target:
						key += "_SELF"
					if "duration" in subject.params:
						key += "_TEMP"
				else:
					key += typeStr

	else:
		key += typeStr

	if subject.type == Game.EventType.CriticalDamage:
		var damage = subject.getParam("damage", 0)
		if subject.getMainActor() == Character.ID.PLAYER:
			subject.damageFormatDict["damage"] = Util.wrapInColor_html(damage, subject.damageColorPlayer_html)
		else:
			subject.damageFormatDict["damage"] = Util.wrapInColor_html(damage, subject.damageColorOpponent_html)

		subject.formatParams["damage"] = subject.damageFormat.format(subject.damageFormatDict)

	if subject.origin is Item:
		subject.formatParams["origin"] = subject.origin.getTranslatedName()

		if subject.origin.character().isPlayer():
			subject.formatParams["actor"] = Util.tra("LOG_PLAYER")
		else:
			subject.formatParams["actor"] = Util.tra("LOG_OPPONENT")
	else:

		var keyword = Game.typeToKeyword(subject.origin)
		var icon = Util.getIcon(keyword)
		if icon:
			subject.formatParams["origin"] = icon
		else:
			subject.formatParams["origin"] = Util.tra(keyword + "_NAME")

	var text
	var depth = subject.getDepth()
	if depth == 0:
		text = "%2.2f" % subject.timestamp + ":  "
	else:
		text = "  ".repeat(depth) + " > "
	text += Util.tra(key)
	text = text.format(subject.formatParams)

	return text

static func setTarget(subject: Receiver, _target):
	subject.target = _target
	if subject.target == Character.ID.PLAYER:
		subject.formatParams["target"] = Util.tra("LOG_PLAYER")
	else:
		subject.formatParams["target"] = Util.tra("LOG_OPPONENT")
