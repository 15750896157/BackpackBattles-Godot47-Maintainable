extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageMeter/DamageMeterEntry.gd")

static func init(subject: Receiver, _player: bool, _source, _absValue, _dps: float, relValue: float, relToLargest: float, _plot, _damageMeter):

	subject.player = _player
	subject.source = _source
	subject.plot = _plot
	subject.damageMeter = _damageMeter
	subject.dps = _dps
	subject.absDamage = _absValue
	subject.plotButton.visible = subject.plot != null
	if subject.plot != null:
		subject.setPlotButtonStyle(subject.plot.getColor(subject.source),
			subject.plot.getSymbol(subject.source), subject.plot.isActive(subject.source))
	else:
		subject.progressBarStylebox.bg_color = Color(2, 1.78, 0.44, 0.37)

	subject.progressBar.value = relToLargest * 100.0

	subject.relDamageLabel.text = str(round(100.0 * relValue)) + "%"

	Util.localizeFonts(subject)
	subject.updateLocale()
	subject.unhighlight()

static func updateLocale(subject: Receiver):
	subject.absDamageLabel.text = Util.tra("UI_DamageMeter_Format").format({
		"absDmg": snapped(subject.absDamage, 0.1),
		"dps": snapped(subject.dps, 0.1)})

	var sourceName = ""
	if typeof(subject.source) == TYPE_INT:
		var icon = Util.getIcon(Game.typeToKeyword(subject.source))
		if icon:
			sourceName += icon + " "
		sourceName += Util.tra(Game.typeToKeyword(subject.source) + "_NAME")
	else:
		sourceName = subject.source.getTranslatedName()

	subject.nameLabel.text = sourceName

static func _gui_input(subject: Receiver, event):
	if subject.plot != null and not Game.combatLog.movedDuringDrag:
		if Util.isClickReleaseEvent(event):
			Game.onClickButton()
			subject.onPlotButtonToggled()

		elif Util.isRightClickReleaseEvent(event):
			Game.onClickButton()
			var isIsolated = true
			for entry in subject.damageMeter.plotToEntry[subject.plot]:
				if entry == subject:
					if not subject.plotButtonActive:
						isIsolated = false
						break
				elif entry.plotButtonActive:
					isIsolated = false
					break

			for entry in subject.damageMeter.plotToEntry[subject.plot]:
				if entry == subject:
					subject.setPlotButtonActive( not isIsolated)
				else:
					entry.setPlotButtonActive(isIsolated)
