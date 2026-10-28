extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Exclusive/Laboratory.gd")

static func doCooldownEffect(subject: Receiver):
	if subject.phase == 1:
		if subject.character().getLucky() >= subject.params["luckt"]:
			var event = subject.useLucky(subject.params["luckt"])
			var numFire = subject.typesDict[subject.Type.Fire]
			subject.giveHeat(subject.params["heat"] + numFire * subject.params["heat_bonus"], event)

	elif subject.phase == 2:
		if subject.character().getHeat() >= subject.params["heatt"]:
			var event = subject.useHeat(subject.params["heatt"])
			var numNature = subject.typesDict[subject.Type.Nature]
			subject.giveSpikes(subject.params["spikes"] + numNature * subject.params["spikes_bonus"], event)

	elif subject.phase == 3:
		if subject.character().getSpikes() >= subject.params["spikest"]:
			var event = subject.useSpikes(subject.params["spikest"])
			var numHoly = subject.typesDict[subject.Type.Holy]
			subject.giveRegeneration(subject.params["regen"] + numHoly * subject.params["regen_bonus"], event)

	elif subject.phase == 4:
		if subject.character().getRegeneration() >= subject.params["regent"]:
			var event = subject.useRegeneration(subject.params["regent"])
			var numVamp = subject.typesDict[subject.Type.Vampiric]
			subject.giveVampirism(subject.params["vampirism"] + numVamp * subject.params["vamp_bonus"], event)

	elif subject.phase == 5:
		if subject.character().getVampirism() >= subject.params["vampt"]:
			var event = subject.useVampirism(subject.params["vampt"])
			var numEngineer = 0
			for item in subject.getAffectedItems():
				if item.isClassItem(Game.Classes_Full.Engineer):
					numEngineer += 1
			subject.giveEmpower(subject.params["empower"] + numEngineer * subject.params["empower_bonus"], event)

	if subject.phase == 5:
		subject.onAfterEffectFinished()
	else:
		subject.activate()

static func onStateChanged(subject: Receiver, _phase: int):
	subject.phase = _phase
	if subject.phase <= 0:
		subject.baseCooldownOverride = subject.getBaseCooldownIndex(0)
	elif subject.phase < 5:
		subject.baseCooldownOverride = subject.getBaseCooldownIndex(subject.phase) - subject.getBaseCooldownIndex(subject.phase - 1)

	subject.fluidTween = Util.refreshTween(subject.fluidTween)
	subject.fluidTween.set_parallel()
	subject.fluidMat.set_shader_parameter("gradient2", subject.gradients[subject.phase])
	subject.fluidTween.tween_property(subject.fluidMat, "shader_parameter/fade", 1.0, subject.DUR)
	subject.fluidTween.tween_property(subject.fluid, "modulate", subject.flashColor, subject.DUR * 0.5)
	subject.fluidTween.tween_property(subject.fluid, "modulate", Color.WHITE, subject.DUR * 0.5).set_delay(subject.DUR * 0.5).from(subject.flashColor)
	subject.fluidTween.tween_callback(Callable(subject, "switchGradient")).set_delay(subject.DUR)

static func getDescription(subject: Receiver, wrapInColor) -> String:
	var descr = subject.descriptor.getDescription()

	for param in subject.params:
		descr = subject.insertParameter(descr, str("p_", param), subject.params[param],
			subject.StatModified.No, false, wrapInColor)

	return subject.insertParameters(descr, wrapInColor)

static func canAffect(subject: Receiver, item):
	return (item.hasType(subject.Type.Fire) or
			item.hasType(subject.Type.Nature) or
			item.hasType(subject.Type.Holy) or
			item.hasType(subject.Type.Vampiric) or
			item.isClassItem(Game.Classes_Full.Engineer))
