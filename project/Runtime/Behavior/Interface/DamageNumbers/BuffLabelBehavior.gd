extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageNumbers/BuffLabel.gd")

static func spawnLabel(subject: Receiver, type, amount, changeType, appliedToOpponent):
	Util.localizeFonts(subject.label)
	subject.gravity_scale = 1
	subject.modulate = Color.WHITE

	var itemBuff = false

	if type == Game.EventType.MissedAttack:
		subject.label.text = subject.labelFormat.format({
			"color": subject.white_html,
			"text": Util.tra("LABEL_Miss")})
		subject.gravity_scale = 5

	elif type == Game.EventType.CriticalResisted:
		subject.label.text = subject.labelFormat.format({
			"color": subject.positiveColor_html,
			"text": Util.tra("LABEL_CritResisted")})

	elif type == Game.EventType.StunResisted:
		subject.label.text = subject.labelFormat.format({
			"color": subject.positiveColor_html,
			"text": Util.tra("LABEL_StunResisted")})

	elif type == Game.EventType.Stun:
		subject.label.text = subject.labelFormat.format({
			"color": subject.negativeColor_html,
			"text": Util.tra("LABEL_Stunned").format({"dur": str(amount, Util.tra("FORMAT_Second"))})})

	elif changeType == subject.ChangeType.Resisted:
		if Game.isBuff(type):
			var text = Util.tra("LABEL_BuffNullified").format({
				"amount": amount,
				"debuff": Util.getIcon(Game.typeToKeyword(type), 40)
			})
			subject.label.text = subject.labelFormat.format({
				"color": subject.negativeColor_html,
				"text": text
			})
		else:
			var text = Util.tra("LABEL_DebuffResisted").format({
				"amount": amount,
				"debuff": Util.getIcon(Game.typeToKeyword(type), 40)
			})
			subject.label.text = subject.labelFormat.format({
				"color": subject.positiveColor_html,
				"text": text
			})

	elif changeType == subject.ChangeType.Protected:
		if Game.isBuff(type):
			var text = Util.tra("LABEL_BuffProtected").format({
				"amount": amount,
				"buff": Util.getIcon(Game.typeToKeyword(type), 40)
			})
			subject.label.text = subject.labelFormat.format({
				"color": subject.positiveColor_html,
				"text": text
			})
		else:
			var text = Util.tra("LABEL_DebuffProtected").format({
				"amount": amount,
				"debuff": Util.getIcon(Game.typeToKeyword(type), 40)
			})
			subject.label.text = subject.labelFormat.format({
				"color": subject.negativeColor_html,
				"text": text
			})

	elif changeType == subject.ChangeType.Reflected:
		var text = Util.tra("LABEL_DebuffReflected").format({
			"amount": amount,
			"debuff": Util.getIcon(Game.typeToKeyword(type), 40)
		})
		subject.label.text = subject.labelFormat.format({
			"color": subject.positiveColor_html,
			"text": text
		})

	else:
		itemBuff = true
		var color

		var positive = Game.isBuff(type)
		if amount < 0:
			positive = not positive

		if appliedToOpponent:
			positive = not positive

		var changePrefix = ""
		if amount > 0:
			changePrefix = "+"

		if positive:
			color = subject.positiveColor_html
		else:
			color = subject.negativeColor_html

		var icon = Util.getIcon(Game.typeToKeyword(type), 40)

		subject.label.text = subject.buffFormat.format({
			"color": color,
			"changeType": changePrefix,
			"amount": amount,
			"icon": icon
		})

	if itemBuff:
		subject.animation.play("ItemBuff")
	else:
		subject.animation.play("Buff")

static func spawnLabelOnItem(subject: Receiver, type: int, amount):
	Util.localizeFonts(subject.label)
	subject.gravity_scale = 1
	subject.modulate = Game.damageNumberColors[type]

	if type == Game.EventType.DealDamage:
		subject.label.text = str("[center]", amount)

		subject.animation.play("Damage")

	elif type == Game.EventType.CriticalDamage:
		subject.label.text = str("[center][shake rate=20 level=30]", amount)
		subject.modulate = Game.damageNumberColors[type]

		subject.animation.play("Damage")

	elif type == Game.EventType.Health:
		subject.label.text = str("[center]+", amount)

		subject.animation.play("Damage")

	elif type == Game.EventType.TemporaryMaxHealth:
		subject.label.text = str("[center]+", amount)

		subject.animation.play("Damage")

	elif type == Game.EventType.MissedAttack:
		subject.label.text = "[center]" + Util.tra("LABEL_Miss")
		subject.animation.play("Damage")

	elif type == Game.EventType.Stamina:
		subject.label.text = str("[center]+", amount)
		subject.animation.play("Damage")

	elif type == Game.EventType.TemporaryMaxStamina:
		subject.label.text = str("[center]+", amount)
		subject.animation.play("Damage")

	elif type == Game.EventType.Fatigue:
		subject.label.text = str("[center]", amount)
		subject.modulate = Game.damageNumberColors[type]
		subject.animation.play("Damage")

	elif type == Game.EventType.DamageBuff:
		var imgBb = Util.imageToBbcode(Util.weaponIcons[Item.Stat.MaxDamage].get_path(), 40)

		if amount > 0:

			subject.label.text = subject.buffFormat.format({
				"changeType": "+",
				"amount": amount,
				"color": subject.positiveColor_html,
				"icon": imgBb
			})
		else:

			subject.label.text = subject.buffFormat.format({
				"changeType": "",
				"amount": amount,
				"color": subject.negativeColor_html,
				"icon": imgBb
			})
		subject.animation.play("ItemBuff")

	elif type == Game.EventType.CooldownAdvance:
		var imgBb = Util.imageToBbcode(Util.weaponIcons[Item.Stat.Cooldown].get_path(), 40)

		amount = snapped(amount, 0.1)

		subject.label.text = subject.buffFormat.format({
			"color": subject.positiveColor_html,
			"changeType": "",
			"amount": str(amount, Util.tra("FORMAT_Second")),
			"icon": imgBb
		})
		subject.animation.play("ItemBuff")

static func spawnStatLabelOnItem(subject: Receiver, stat: int, amount, onOpponent):
	Util.localizeFonts(subject.label)
	subject.gravity_scale = 1

	var prettyAmount = str(snapped(amount, 0.1))
	prettyAmount += CharacterStatIcon.suffixes[stat]

	var positive: bool = amount > 0

	var color
	if positive:
		if onOpponent:
			color = subject.negativeColor_html
		else:
			color = subject.positiveColor_html
	else:
		if onOpponent:
			color = subject.positiveColor_html
		else:
			color = subject.negativeColor_html

	if not positive:
		stat *= - 1
	var imgBb = Util.imageToBbcode(Util.statIcons[stat].get_path(), 50)

	subject.label.text = subject.buffFormat.format({
		"color": color,
		"changeType": "+" if positive else "",
		"amount": prettyAmount,
		"icon": imgBb
	})
	subject.animation.play("StatChange")
