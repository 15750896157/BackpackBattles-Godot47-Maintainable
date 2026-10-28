extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/GoldCounter.gd")

static func updateTooltip(subject: Receiver, forRound):
	if CustomRules.isSwitchMode():
		subject.tooltipArea.keyword = "Gold_SwitchMode"
	else:
		subject.tooltipArea.keyword = "Gold"
	subject.tooltipArea.params = {"bonusGold": Util.wrapInColor(
		"+" + str(int(Game.getGoldGain(forRound))), Util.paramColor)}

static func updateCounting(subject: Receiver, change):
	if change == 0: return

	if Util.time <= subject.lastChangeTime + 0.1:
		change += subject.lastChange

	if change > 0:
		subject.bonusCounter.prefix = "+"
		subject.bonusCounter.set("theme_override_colors/font_color", subject.positiveChangeColor)
	else:
		subject.bonusCounter.prefix = ""
		subject.bonusCounter.set("theme_override_colors/font_color", subject.negativeChangeColor)

	subject.bonusCounter.show()
	subject.bonusCounter.setCurrent(change)
	subject.bonusCounter.present()

	subject.lastChangeTime = Util.time
	subject.lastChange = change

	subject.setTarget(Game.getGold())
