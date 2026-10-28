extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForGemSocket:
	const Receiver = preload("res://Items/GemSocket.gd")

	static func onDropGem(subject: Receiver, droppedGem):
		if subject.gem != null:

			subject.gem.onHotSwapHoverWithGemEnd()
			subject.gem.pickup()
		subject.gem = droppedGem
		subject.onHoverEndWithGem()
		subject.showSocket()
		if subject.gem.placedByPlayer:
			subject.gem.createGemParticles()

class ForGingerbreadMan:
	const Receiver = preload("res://Items/GingerbreadMan.gd")

	static func doCooldownEffect(subject: Receiver):
		if subject.character().getLucky() >= subject.luckNeeded:
			if subject.character().getHeat() >= subject.heatNeeded:
				if subject.character().getMana() >= subject.manaNeeded:

					EventBus.setLoggingMode(EventBus.LoggingMode.Delayed)
					subject.useLucky(subject.luckNeeded)
					subject.useHeat(subject.heatNeeded)
					subject.useMana(subject.manaNeeded)
					subject.giveEmpower(subject.getP5())
					subject.giveRegeneration(subject.getP6())
					EventBus.flushLoggingQueue()

					subject.giveMaxHealth(subject.getP_m("maxhealth_use"))
					var activationParticles = ObjectPool.particleOneShot(subject.activationParticlesScene, subject)
					activationParticles.global_rotation = 0

		subject.activate()

class ForGoobert:
	const Receiver = preload("res://Items/Goobert.gd")

	static func onItemActivated(subject: Receiver, event):
		subject.activations += 1

		if subject.activations == subject.getP1():
			subject.activations = 0
			subject.doCooldownEffect()
			subject.activate()

			if subject.doubleActivationChance > 0 and Util.flip(subject.doubleActivationChance):
				subject.doCooldownEffect()
				subject.activate()

			subject.showCooldownSmooth(subject.activations / subject.activationsToTrigger, true)
		else:
			subject.showCooldownSmooth(subject.activations / subject.activationsToTrigger, false)

		subject.triggerTime = subject.activationsToTrigger - subject.activations
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown, null, false, event)

class ForGreatsword:
	const Receiver = preload("res://Items/Greatsword.gd")

	static func empowerChanged(subject: Receiver, amount, event):
		if not subject.buffed and subject.character().getEmpower() >= subject.empowerNeeded:
			subject.setState(true)
			subject.setBaseCooldown(subject.buffedCooldown)
			Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.StaminaCost)

		elif subject.buffed and subject.character().getEmpower() < subject.empowerNeeded:
			subject.setState(false)
			subject.resetBaseCooldown()
			Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.StaminaCost)
