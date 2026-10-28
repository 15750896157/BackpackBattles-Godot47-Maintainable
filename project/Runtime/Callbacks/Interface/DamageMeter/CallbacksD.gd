extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForDamageMeterTotal:
	const Receiver = preload("res://Interface/DamageMeter/DamageMeterTotal.gd")

	static func init(subject: Receiver, absValue, dps: float):
		subject.absDamageLabel.text = Util.tra("UI_DamageMeter_Format").format({
			"absDmg": snapped(absValue, 0.1),
			"dps": snapped(dps, 0.1)})

		Util.localizeFonts(subject)
		subject.totalLabel.updateLocale()
