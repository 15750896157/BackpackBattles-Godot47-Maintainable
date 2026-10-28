extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/DamageMeter/DamageMeterEntry.gd")

static func preset(subject: Receiver):
	subject.nameLabel = subject.get_node("Name")
	subject.progressBar = subject.get_node("ProgressBar")
	subject.relDamageLabel = subject.get_node("RelDamage")
	subject.absDamageLabel = subject.get_node("AbsoluteDamage")
	subject.panel = subject.get_node("Panel")
	subject.plotButton = subject.get_node("PlotButton")

	subject.add_to_group("Localized")
	Util.localizeFonts(subject)
	subject.nameLabel.set_message_translation(false)

	subject.progressBarStylebox = subject.progressBar.get("theme_override_styles/fg")

static func onShowPlotLine(subject: Receiver):
	subject.progressBarStylebox.bg_color = subject.plotButtonActiveColor
	subject.plotButton.modulate = subject.plotButtonActiveColor
	subject.nameLabel.set(subject.defaultColorProp, subject.textActiveColor)
	subject.nameLabel.set(subject.defaultColorProp, subject.textActiveColor)
	subject.relDamageLabel.set(subject.fontColorProp, subject.textActiveColor)
	subject.absDamageLabel.set(subject.fontColorProp, subject.textActiveColor)

static func onHidePlotLine(subject: Receiver):
	subject.progressBarStylebox.bg_color = subject.plotButtonInactiveColor
	subject.plotButton.modulate = subject.plotButtonInactiveColor
	subject.nameLabel.set(subject.defaultColorProp, subject.textInactiveColor)
	subject.relDamageLabel.set(subject.fontColorProp, subject.textInactiveColor)
	subject.absDamageLabel.set(subject.fontColorProp, subject.textInactiveColor)
