extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func getRarity(subject: Receiver) -> int:
	if subject.pve_is_view(): return {"common": subject.Rarity.Common, "rare": subject.Rarity.Rare, "epic": subject.Rarity.Epic, "legendary": subject.Rarity.Legendary}.get(str(subject.pve_definition().get("rarity", "common")), subject.Rarity.Common)
	return subject.descriptor.rarity

static func getMinDamage(subject: Receiver, damSource) -> int:
	if subject.pve_is_view(): return int(ceil(subject.pve_stat("damage")))
	var override = subject.statDisplayOverrides[subject.Stat.MinDamage]
	if override: return override

	var minDam = ceil(subject.descriptor.minDam + subject.bonusMinDam)
	if subject.hasCharacter():
		if subject.canBeEmpowered():
			minDam = minDam + subject.character().getBuffDamageMod()

		minDam *= subject.getTypedDamageFactor(damSource)

	minDam = round(minDam * subject.bonusDamageFactor)
	minDam = max(minDam, 0)

	return minDam

static func getMaxDamage(subject: Receiver, damSource) -> int:
	if subject.pve_is_view(): return int(ceil(subject.pve_stat("damage")))
	var override = subject.statDisplayOverrides[subject.Stat.MaxDamage]
	if override: return override

	var maxDam = ceil(subject.descriptor.maxDam + subject.bonusMaxDam)
	if subject.hasCharacter():
		if subject.canBeEmpowered():
			maxDam = maxDam + subject.character().getBuffDamageMod()

		maxDam *= subject.getTypedDamageFactor(damSource)

	maxDam = round(maxDam * subject.bonusDamageFactor)
	maxDam = max(maxDam, 0)

	return maxDam

static func getSpeed(subject: Receiver) -> float:
	if subject.pve_is_view(): return subject.pve_stat("base_cooldown") / maxf(0.001, subject.pve_stat("cooldown")) if subject.pve_stat("base_cooldown") > 0 else 1.0
	var override = subject.statDisplayOverrides[subject.Stat.Speed]
	if override: return override

	if subject.hasCharacter():
		var speed_ = subject.getBaseSpeed() + subject.getStackSpeedMods()
		var modifiedSpeed: float
		if speed_ >= 0:
			modifiedSpeed = 1.0 + speed_
		else:
			modifiedSpeed = 1.0 / (1.0 - speed_)

		modifiedSpeed = clamp(modifiedSpeed, 0.1, 10.0)
		return modifiedSpeed
	else:
		return 1.0

static func adjustCooldown(subject: Receiver):
	var adjustedCooldown = subject.getCooldown()
	if subject.ownerType == subject.Owner.Opponent and (Game.isBelowLeague(Game.Leagues.Master) or Game.curMode == Game.Mode.Lobbies):
		adjustedCooldown *= Util.rng.randf_range(0.975, 1.05)
	else:
		adjustedCooldown *= Util.rng.randf_range(0.95, 1.05)

	return adjustedCooldown

static func addBonusDamage(subject: Receiver, damage, removable: bool):
	if damage != 0:
		subject.bonusMinDam += damage
		subject.bonusMaxDam += damage
		if removable:
			Util.eassert(damage > 0)
			subject.removableDam += damage
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.MinDamage)
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.MaxDamage)

		if removable:
			subject.spawnLabel(Game.EventType.DamageBuff, damage)

static func playOutOfStaminaAnimation(subject: Receiver):
	subject.animation.play("NoStamina")
	var label = ObjectPool.instantiate(subject.outOfStaminaLabelScene)
	Game.UINode.add_child(label)
	label.global_position = subject.global_position
	if subject.ownerType == subject.Owner.PlayerInventory:
		Game.numTimesOutOfStamina += 1
		Sound.playSound(subject.outOfStaminaSound, - 3, 1.0)
	else:
		Sound.playSound(subject.outOfStaminaSound, - 4, 1.4)

static func useStamina(subject: Receiver, amount):
	var res = subject.character().useStamina(amount)
	if res == subject.character().StaminaResult.Insufficient:
		subject.addMetric(Game.ItemMetrics.OutOfStamina, 1, null, true)
		var event = Game.combatLog.createEvent_OutOfStamina(subject, subject.character().playerId)
		EventBus.logEvent(event)
		Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown)
		subject.playOutOfStaminaAnimation()
	else:
		EventBus.emitSignal(subject, "used_stamina", [amount])
		subject.staminaChanged(amount, subject.StackChangeType.Used_Player, true)
	return res

static func discard(subject: Receiver, discardGems):
	if subject.pve_is_view(): Expedition.bridge.reset_native_visual(subject)
	if discardGems:
		for gem in subject.getGemsNoNull():
			gem.discard()

	if subject.hovered_state:
		subject.hoverEnd()
	subject.clearTooltip()
	subject.disableTooltip()
	subject.disablePicking()
	subject.disableFocus()
	Game.onItemUnderMouseExited(subject)
	Util.disconnectAll(subject)

	if subject.isOwnable():
		ItemBook.onOwnableItemRemoved(subject)

	if subject.pooled:
		subject.clearDynamicTypes()
		Util.killTween(subject.shadowTween)
		subject.resetSprite()

		if subject.placed:
			subject.cleanCachedAffectedItems()
			subject.placed = false

		ObjectPool.returnInstance(subject, subject.descriptor.scene)
	else:

		subject.clickArea.hide()
		subject.queue_free()

static func popIn(subject: Receiver, withParticles: bool, speed, jump):
	subject.shadowTween = Util.refreshTween(subject.shadowTween)
	subject.setSpriteScale(Vector2.ZERO)
	subject.updateShadow()

	var scaledUp = subject.spriteScale * 1.1
	var totalScaleDur = 0.5 / speed
	var scaleDur1 = 0.3 / speed

	subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	subject.shadowTween.set_parallel()

	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), scaledUp,
		scaleDur1).set_ease(Tween.EASE_IN_OUT)
	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale,
		totalScaleDur - scaleDur1).from(scaledUp).set_ease(
			Tween.EASE_IN_OUT).set_delay(scaleDur1)

	if jump:
		var yPos = subject.sprite.position.y
		var yOffset = Util.rng.randf_range( - 90.0, - 40.0)
		var totalJumpDur = 0.3 / speed

		var jumpDur1 = 0.15 / speed
		subject.shadowTween.tween_property(subject.sprite, "position:y", yOffset,
			jumpDur1).set_ease(Tween.EASE_OUT)
		subject.shadowTween.tween_property(subject.sprite, "position:y", yPos,
			totalJumpDur - jumpDur1).set_ease(Tween.EASE_IN).from(yOffset).set_delay(jumpDur1)

	if withParticles:
		var particles = subject.createParticles(subject.sparksScene, Vector2(0.9, 0.9))
		particles.modulate = Game.rarityColors[subject.getRarity()]

static func createParticles(subject: Receiver, scene, baseScale):
	var particles = ObjectPool.instantiate(scene)
	Game.mainNode.add_child(particles)
	particles.global_position = subject.global_position
	particles.z_index = Util.getGlobalZ(subject) - 1
	var numCells = subject.getNumOccupiedCells()
	numCells += subject.getNumBagCells()
	particles.scale = baseScale * sqrt(numCells)
	particles.restart()
	ObjectPool.returnAfter(1.0, particles)
	return particles

static func dropImpulse(subject: Receiver, direction, tweenBouncyness: bool):

	if tweenBouncyness:
		var bouncynessTween = subject.create_tween().set_parallel()
		bouncynessTween.tween_property(subject.physics_material_override,
			"bounce", 0.0, subject.frictionTime).from(subject.baseBounce)
		bouncynessTween.tween_property(subject.physics_material_override,
			"friction", 1.0, subject.frictionTime).from(subject.baseFriction)

	var impulseOffset = Vector2(Util.rng.randf_range( - subject.offset, subject.offset),
								Util.rng.randf_range( - subject.offset, subject.offset))
	if direction == null:
		direction = (Vector2(
					Util.rng.randf_range( - subject.impulse, subject.impulse),
					Util.rng.randf_range( - subject.impulse, subject.impulse))
					+ subject.momentum * subject.momentumFactor)

	var impulse2: Vector2 = direction * (0.5 + 0.5 * subject.mass)

	subject.apply_impulse(impulse2, impulseOffset)

static func playActivationAnimation_Jump(subject: Receiver, height, maxScale: float):
	subject.shadowTween = Util.refreshTween(subject.shadowTween)
	subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	var startPos = subject.sprite.global_position.y
	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale * maxScale, 0.1).set_ease(Tween.EASE_IN_OUT)
	subject.shadowTween.parallel().tween_property(subject.sprite, "global_position:y",
		startPos - height, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale, 0.2).set_ease(Tween.EASE_IN_OUT)
	subject.shadowTween.parallel().tween_property(subject.sprite, "global_position:y",
		startPos, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(0.05)
