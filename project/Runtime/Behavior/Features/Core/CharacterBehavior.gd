extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Character.gd")

static func setClass(subject: Receiver, _class: int, _chibi: bool):
	subject.characterClass = _class
	subject.chibi = _chibi
	var classResource = Game.classResources[subject.characterClass]
	if subject.playerId == subject.ID.PLAYER:
		subject.setClassResource(classResource)
	else:
		subject.setSprite(classResource, subject.chibi)

	subject.nameBanner.texture = Game.classNameBanners[subject.characterClass]

	subject.emit_signal("class_changed")

static func setClassResource(subject: Receiver, classResource: CharacterClass):
	if Expedition.enabled and Expedition.db != null:
		subject.pve_apply_role_stats()
		subject.setSprite(classResource, subject.chibi)
		return
	subject.setMaxHealth(classResource.health)
	subject.baseMaxStamina = classResource.stamina
	subject.setMaxStamina(subject.baseMaxStamina)
	subject.setSprite(classResource, subject.chibi)

static func combatToShop(subject: Receiver):
	if subject.playerId == subject.ID.PLAYER:
		if Expedition.enabled: subject.pve_reset_presentation("shop")
		else: subject.call_deferred("cleanse")
		subject.animation.play("EnterShopFromCombat")
	else:
		subject.animation.play("OpponentLeaveCombat")

static func combatToTitle(subject: Receiver):
	if subject.playerId == subject.ID.PLAYER:
		if Expedition.enabled: subject.pve_reset_presentation("title")
		else: subject.call_deferred("cleanse")
		subject.animation.play("CombatToTitle")
		subject.animation.queue("StartOnTitle")
	else:
		subject.animation.play("OpponentLeaveCombat")

static func playSound(subject: Receiver, stream, volume, pitch, force):
	if force:
		subject.audioPlayer.stop()

	if not subject.audioPlayer.playing:
		subject.audioPlayer.stream = stream
		subject.audioPlayer.volume_db = volume - 3
		subject.audioPlayer.pitch_scale = pitch + 0.1
		subject.audioPlayer.play()

static func combatStart(subject: Receiver):
	subject.stunnedDuration = 0.0
	subject.set_physics_process(true)
	subject.combatDefaultPos = subject.spriteNode.position
	subject.tickCounter = 0
	subject.tickTimer.start()

	if subject.autoRageItem != null:
		subject.autoRageTimer.start(subject.AUTO_RAGE_DELAY)

static func combatEnd(subject: Receiver):
	subject.set_physics_process(false)
	subject.tickTimer.stop()
	subject.attackMovingForward = false

	for buff in subject.buffs:
		subject.buffs[buff].combatEnd()
	subject.battleRageTimer.stop()
	subject.autoRageTimer.stop()
	subject.invulnerabilityTimer.stop()

static func randDmgNumberPos(subject: Receiver):
	return subject.global_position + subject.DMG_NUM_CENTER[subject.playerId] + Vector2(
		Util.rng.randf_range( - subject.DMG_NUM_OFFSET.x, subject.DMG_NUM_OFFSET.x),
		Util.rng.randf_range( - subject.DMG_NUM_OFFSET.y, subject.DMG_NUM_OFFSET.y))

static func randHealNumberPos(subject: Receiver):
	return subject.global_position + subject.HEAL_NUM_CENTER[subject.playerId] + Vector2(
		Util.rng.randf_range( - subject.DMG_NUM_OFFSET.x, subject.DMG_NUM_OFFSET.x),
		Util.rng.randf_range( - subject.DMG_NUM_OFFSET.y, subject.DMG_NUM_OFFSET.y))

static func randDmgNumberDir(subject: Receiver):
	var direction = subject.dmgNumBaseDir
	direction = direction.rotated(Util.rng.randf_range(
		subject.dmgNumMinAngle, subject.dmgNumMaxAngle))
	if subject.playerId == subject.ID.OPPONENT:
		direction.x *= - 1

	return direction

static func randBuffLabelPos(subject: Receiver):
	return subject.global_position + subject.BUFFLABEL_CENTER[subject.playerId] + Vector2(
		Util.rng.randf_range( - subject.BUFFLABEL_OFFSET.x, subject.BUFFLABEL_OFFSET.x),
		Util.rng.randf_range( - subject.BUFFLABEL_OFFSET.y, subject.BUFFLABEL_OFFSET.y))

static func reincarnate(subject: Receiver, healAmount: int, isHeal: bool, item, triggerEvent):
	subject.setCurrentHealth(0)

	healAmount = min(subject.getMaxHealth(), healAmount)
	subject.setCurrentHealth(healAmount)
	var event = Game.combatLog.createEvent_Reincarnate(item, healAmount, triggerEvent)
	item.addMetric(Game.ItemMetrics.Heal, healAmount)
	EventBus.emitEvent(subject, "reincarnated", event, [event])
	return event

static func drainStamina(subject: Receiver, amount, item, triggerEvent):
	var drained = min(subject.curStamina, amount)
	subject.curStamina -= drained
	var event = Game.combatLog.createEvent_DrainStamina(drained, item, subject.playerId, triggerEvent)
	EventBus.logEvent(event)
	item.staminaChanged(drained, Item.StackChangeType.Removed_Opponent)
	return event

static func changeMaxHealthTemporary(subject: Receiver, amount, item, triggerEvent):
	if amount != 0:
		subject.temporaryMaxHealth += amount

		assert (item == null or amount > 0)
		subject.curHealth += amount
		if item != null:
			var event = Game.combatLog.createEvent_TemporaryMaxHealth(item, amount, triggerEvent)
			EventBus.logEvent(event)
		subject.emit_signal("health_changed_ui")

static func recalculateMaxStamina(subject: Receiver):
	subject.staminaUpdateQueued = false
	subject.maxStamina = subject.getBaseMaxStamina()
	for item in subject.INVENTORY.getItems():
		if item.descriptor == ItemBook.staminaSackDescriptor:
			subject.maxStamina += 1
	subject.curStamina = subject.maxStamina
	subject.emit_signal("max_stamina_changed_ui")

static func win(subject: Receiver):
	subject.winParticles.activate()
	subject.damageAnimation.play("Win")
	subject.spriteAnimation.stop()
	subject.spriteAnimation.speed_scale = 1.0
	subject.spriteAnimation.play("Jump")

static func invulnerabilityEnded(subject: Receiver):
	subject.invulnerable = false
	var event = Game.combatLog.createEvent_InvulnerableEnd(subject.invulnerabilityItem, subject.playerId)
	EventBus.emitEvent(subject, "character_invulnerable_end", event, [event])
	Game.combatLog.snapshotCharacterStat(subject, subject.Stat.Invulnerable, false, event)
	subject.playInvulnerableAnimation(false)

static func playStunAnimation(subject: Receiver, duration):
	if duration > 0:
		subject.combatAnimation.play("StunStart")
		Util.spawnBuffLabel(Game.EventType.Stun, subject.randBuffLabelPos(), duration)
	else:
		subject.combatAnimation.play("StunEnd")

static func getTotalStaminaUsage(subject: Receiver):
	var totalStaminaUse = 0.0
	for item in subject.INVENTORY.getItems():
		var staminaUse = item.getStaminaCost()
		if item.getCooldown() > 0:
			staminaUse /= item.getCooldown()
		totalStaminaUse += staminaUse
	return totalStaminaUse

static func setStacksLogged(subject: Receiver, buffType, amount: int, item, triggerEvent):
	var curStacks = subject.getStacks(buffType)
	if amount < curStacks:
		subject.loseStacks(buffType, curStacks - amount, item, triggerEvent)
	elif amount > curStacks:
		subject.gainStacks(buffType, amount - curStacks, item, triggerEvent)

static func gainPoison(subject: Receiver, amount: int, item, triggerEvent):
	var event = subject.gainStacks(Game.EventType.Poison, amount, item, triggerEvent)
	if amount > 0:
		subject.damageAnimation.stop()
		subject.damageAnimation.play("Poison")
	return event

static func changeDamageResistance(subject: Receiver, amount: float, item, duration, triggerEvent):

	subject.damageResistance += amount
	Game.combatLog.snapshotCharacterStat(subject, subject.Stat.DamageResistance)
	if item != null:
		var event = Game.combatLog.createEvent_DamChange(item, - amount,
			true, duration, null, triggerEvent)
		EventBus.logEvent(event)

static func critResisted(subject: Receiver) -> bool:
	var resisted = subject.critResistanceRng.rollPercent(subject.critResistance)
	if not resisted:
		if subject.critResistStacks > 0:
			subject.critResistStacks -= 1
			Game.combatLog.snapshotCharacterStat(subject, subject.Stat.CritResistStacks, true)
			return true
	return resisted

static func randAnimationSpeed(subject: Receiver) -> void :
	subject.idleAnimation.speed_scale = subject.idleAniDefaultSpeed * Util.rng.randf_range(0.8, 1.2)

	subject.idleAniSpeedTimer.start(Util.rng.randf_range(2, 5))

	subject.sprite.syncIdleAnis()

static func endBattleRage(subject: Receiver):
	subject.battleRageTimer.stop()
	var event = Game.combatLog.createEvent_BattleRageEnd(subject.playerId)
	EventBus.emitEvent(subject, "battle_rage_ended", event, [event])
	Game.combatLog.snapshotCharacterStat(subject, subject.Stat.BattleRage, false, event)
	subject.playBattleRageAnimation(false)

static func playBattleRageAnimation(subject: Receiver, rageStart):
	if rageStart:
		subject.battleRageParticles.activate()
		subject.battleRageAnimation.stop()
		subject.battleRageAnimation.play("BattleRage")
		if Game.classResources[subject.characterClass].battleRageSound:
			subject.playSound(Game.classResources[subject.characterClass].battleRageSound, 3)
	else:
		subject.battleRageParticles.deactivate()
		subject.battleRageAnimation.play("BattleRageEnded")

static func setStat(subject: Receiver, stat, value):
	match stat:
		subject.Stat.Health:
			subject.setCurrentHealth(value)
		subject.Stat.MaxHealth:
			subject.setTemporaryMaxHealth(value)
		subject.Stat.Stamina:
			subject.setCurrentStamina(value)
		subject.Stat.MaxStamina:
			subject.setTemporaryMaxStamina(value - subject.maxStamina)
		subject.Stat.Stunned:
			subject.playStunAnimation(value)
		subject.Stat.Invulnerable:
			subject.playInvulnerableAnimation(value)
		subject.Stat.BattleRage:
			subject.playBattleRageAnimation(value)
