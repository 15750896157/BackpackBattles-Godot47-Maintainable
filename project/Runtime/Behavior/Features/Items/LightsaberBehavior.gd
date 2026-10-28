extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Lightsaber.gd")

static func onPrepare(subject: Receiver):
	subject.setState(false)
	subject.connectForCombat(subject.character(), "blinding_light_ended", "onBlindingLightEnded")
	subject.connectForCombat(subject.opponent(), "character_blind_changed", "onOpponentBlindChanged")
	subject.connectForCombat(subject.character(), "character_regeneration_changed", "onRegenChanged")

static func onRegenChanged(subject: Receiver, amount, triggerEvent):
	if amount < 0: return

	if not subject.character().blindingLightActive and subject.character().getRegeneration() >= subject.regenNeeded:

		subject.setState(true, true)
		subject.character().startBlindingLight()
		var event = subject.useRegeneration(subject.regenNeeded, triggerEvent)
		var duration = subject.getP_m("dur_blind")
		subject.inflict(duration, event)
		Util.createPulse(subject.activationPulse, subject, subject.global_position)

		subject.activate(null, false)
		subject.blindingLightTimer.start(duration)
