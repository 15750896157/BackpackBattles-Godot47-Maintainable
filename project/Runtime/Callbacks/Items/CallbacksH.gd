extends RefCounted
## Related leaf callbacks. Each namespace keeps its original typed scene receiver.

class ForHammer:
	const Receiver = preload("res://Items/Hammer.gd")

	static func onDealtDamage(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit() and subject.rollChance():
			subject.stun(subject.getP_m("dur_stun"), damageRes.event)
			var particles = ObjectPool.particleOneShot(subject.stunParticles, subject.sprite)
			particles.position = Vector2(175, - 144)

class ForHeartContainer:
	const Receiver = preload("res://Items/HeartContainer.gd")

	static func onRegenChanged(subject: Receiver, amount, event):
		if amount > 0 and not subject.activated and subject.character().getRegeneration() >= subject.regenNeeded:
			subject.setState(true, true)
			subject.useRegeneration(subject.regenNeeded, event)
			subject.giveMaxHealth(subject.getP_m("maxhealth"), event)
			subject.giveEmpower(subject.getP4(), event)
			subject.character().addHealingEfficiency(subject.getP5() / 100.0)

class ForHeroLongsword:
	const Receiver = preload("res://Items/HeroLongsword.gd")

	static func getCraftingOffset(subject: Receiver, forDirection):
		match forDirection:
			subject.FaceDirection.UP:
				return Vector2(0, - 1)
			subject.FaceDirection.DOWN:
				return Vector2.ZERO
			subject.FaceDirection.LEFT:
				return Vector2( - 1, 0)
			subject.FaceDirection.RIGHT:
				return Vector2.ZERO

class ForHoloFireLizard:
	const Receiver = preload("res://Items/HoloFireLizard.gd")

	static func doRevealEffect(subject: Receiver):
		subject.character().changeEffectDamageFactor(subject.damFactor)
		var dam = subject.descriptor.minDam + subject.getP1() * subject.chainPosition
		var res = subject.dealEffectDamage(dam)
		subject.giveHeat(subject.heat)

		subject.activate(res)
		subject.fireParticles.activate()

class ForHungryBlade:
	const Receiver = preload("res://Items/HungryBlade.gd")

	static func onPreDealDamage_early(subject: Receiver, damageRes: DamageResult):
		if damageRes.hasHit():
			var numRegen = subject.character().getRegeneration()
			if numRegen >= subject.regenNeeded:
				var event = subject.useRegeneration(subject.regenNeeded)
				subject.giveVampirism(subject.vampirismForRegen, event)
				ObjectPool.particleOneShot(subject.activationParticles, subject.sprite)
