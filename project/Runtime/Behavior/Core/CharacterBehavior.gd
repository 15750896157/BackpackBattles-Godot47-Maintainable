extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Core/Character.gd")

static func _ready(subject: Receiver) -> void :
	Util.localizeFonts(subject)

	Util.addFallbackFonts(subject.nameLabel.get("theme_override_fonts/font"))

	subject.INVENTORY = subject.inventoryScene.instantiate()
	subject.get_parent().add_child(subject.INVENTORY)
	subject.INVENTORY.character = subject

	if subject.playerId == subject.ID.OPPONENT:
		subject.animation.play("OpponentInit")
		subject.animation.advance(0.01)
		subject.INVENTORY.position = Vector2(subject.position.x - 450, 60)

	elif subject.playerId == subject.ID.PLAYER:
		subject.animation.play("StartOnTitle")
		subject.INVENTORY.position = Vector2(subject.position.x - 300, 60)
		Util.addFallbackFonts(subject.nameLineEdit.get("theme_override_fonts/font"))

	subject.spikeDamageSource = DamageSource.new().init(subject, DamageSource.Type.Spikes, 1)
	subject.spikeDamageSource.flags = DamageSource.chipDamageFlags + DamageSource.Flags.CanCrit

	subject.poisonDamageSource = DamageSource.new().init(subject, DamageSource.Type.Poison, 1)
	subject.poisonDamageSource.flags = DamageSource.chipDamageFlags + DamageSource.Flags.CanCrit

	for buffType in range(Game.EventType.Block, Game.EventType.Cold + 1):
		subject.buffs[buffType] = Buff.new().init(buffType, subject,
		subject.get_node("CombatUI/" + Game.eventTypeKeys[buffType]),
		"character_" + Game.eventTypeKeys[buffType].to_lower() + "_changed")

	for damageType in DamageSource.Type.values():
		subject.typedDamageFactors[damageType] = 0.0

static func setSprite(subject: Receiver, classResource, _chibi: bool):
	subject.chibi = _chibi

	var spriteScene
	if Game.isClassUnlocked():

		if not subject.chibi or not classResource.chibiSprite:
			spriteScene = classResource.sprite
		else:
			spriteScene = classResource.chibiSprite
	else:
		spriteScene = classResource.notUnlockedSprite

	if not spriteScene: return

	if Expedition.enabled:
		Util.killTween(subject.attackTween)
		subject.attackMovingForward = false
		subject.idleAniSpeedTimer.stop()
		if is_instance_valid(subject.spriteAnimation): subject.spriteAnimation.stop()
		if is_instance_valid(subject.idleAnimation): subject.idleAnimation.stop()
		if is_instance_valid(subject.sprite) and subject.sprite.get_parent() != null:
			subject.sprite.get_parent().remove_child(subject.sprite)
	subject.sprite.queue_free()
	subject.sprite = spriteScene.instantiate()
	if Expedition.enabled: subject.sprite.name = "Sprite2D"
	subject.spriteNode.add_child(subject.sprite)
	subject.spriteAnimation = subject.sprite.get_node("SpriteAnimationPlayer")
	subject.idleAnimation = subject.sprite.get_node("IdleAnimationPlayer")
	subject.idleAniDefaultSpeed = subject.idleAnimation.speed_scale

static func pve_apply_role_stats(subject: Receiver):
	if Expedition.db == null: return
	var role = "alchemist" if subject.characterClass == Game.Classes_Full.Reaper else "armorer"
	var data = Expedition.db.get_row("characters", role)
	if data.is_empty(): return
	subject.temporaryMaxHealth = 0.0
	subject.temporaryMaxHealthGain = 1.0
	subject.setMaxHealth(float(data.max_health))
	subject.setCurrentHealth(float(data.starting_health))
	subject.baseMaxStamina = float(data.stamina_max)
	subject.setMaxStamina(subject.baseMaxStamina)
	subject.baseStaminaRegen = float(data.stamina_regen_per_sec)
	subject.staminaRegen = subject.baseStaminaRegen
	subject.fillUpStamina()

static func pve_set_combat_anchor(subject: Receiver):
	var name = "OpponentInit" if subject.playerId == subject.ID.OPPONENT else "EnterCombatFromShop"
	if not subject.animation.has_animation(name): return
	var original = subject.animation.get_animation(name)
	for track in range(original.get_track_count()):
		if original.track_get_path(track) == NodePath("Mirroring/Sprite2D:position"):
			var key_count = original.track_get_key_count(track)
			if key_count > 0: subject.combatDefaultPos = original.track_get_key_value(track, key_count - 1)
			return

static func pve_reset_presentation(subject: Receiver, scene_name: String):
	subject.combatEnd()
	Util.killTween(subject.attackTween)
	subject.attackMovingForward = false
	subject.animation.clear_queue()
	if scene_name != "combat": subject.animation.stop()
	subject.combatAnimation.stop()
	subject.damageAnimation.play("RESET")
	subject.damageAnimation.advance(0.0)
	subject.damageAnimation.stop()
	subject.spriteNode.show()
	subject.spriteNode.modulate = Color.WHITE
	subject.spriteNode.scale = Vector2.ONE
	subject.idleAniSpeedTimer.stop()
	if is_instance_valid(subject.idleAnimation): subject.idleAnimation.speed_scale = subject.idleAniDefaultSpeed
	for particles in [subject.loseParticles, subject.winParticles]:
		particles.restart()
		particles.emitting = false
	subject.audioPlayer.stop()
	if scene_name == "combat":
		subject.cleanse()
		subject.pve_set_combat_anchor()
	else:
		subject.opponent = null
		subject.cleanse()
		if scene_name == "title": subject.pve_apply_role_stats()

static func prepare(subject: Receiver):
	subject.staminaRegen = subject.baseStaminaRegen
	var bonusHealth = subject.getMaxHealth() * ((CustomRules.getHealthMultiplier() - 100.0) / 100.0)
	subject.changeMaxHealthTemporary(bonusHealth)

	subject.accuracyRng.reset()
	subject.critRng.reset()
	subject.critResistanceRng.reset()
	subject.stunResistanceRng.reset()

	if Game.isBelowLeague(Game.Leagues.Master) or Game.curMode == Game.Mode.Lobbies:
		if subject.playerId == subject.ID.PLAYER:
			subject.accuracyRng.setBias( - 0.2)
			subject.critRng.setBias( - 0.2)
		else:
			subject.accuracyRng.setBias(0.2)
			subject.critRng.setBias(0.2)

	subject.autoRageItem = null
	var hasBattleRageStarter = false
	for item in subject.INVENTORY.getItems():
		if item.hasTag(Item.Tag.BattleRage):
			hasBattleRageStarter = true
			break

	if not hasBattleRageStarter:
		var battleRageItems = []
		for item in subject.INVENTORY.getItemsAndGems():
			if item.isBattleRageItem():
				battleRageItems.push_back(item)

		if not battleRageItems.is_empty():
			subject.autoRageItem = battleRageItems.pick_random()

static func cleanse(subject: Receiver):
	subject.isDead = false
	subject.temporaryMaxHealth = 0
	subject.temporaryMaxHealthGain = 1.0
	subject.staminaRegen = subject.baseStaminaRegen
	subject.healToFull()
	subject.emit_signal("max_health_changed_ui")
	subject.setTemporaryMaxStamina(0)
	subject.fillUpStamina()
	subject.endStun()
	subject.setBlock(0)

	for buffType in subject.buffs:
		subject.buffs[buffType].reset()

	if subject.invulBubbleVisible:
		subject.playInvulnerableAnimation(false)

	subject.invulnerable = false
	subject.invulnerabilityItem = null

	subject.damageResistance = 0.0
	subject.damageReduction = 0
	subject.dodgeStacks = 0
	subject.critResistance = 0.0
	subject.critResistStacks = 0
	subject.stunResistance = 0.0
	subject.unhealingAmount = 0.0
	subject.healingEfficiency = 1.0
	subject.critTokens = 0
	subject.debuffResistStacks = 0
	subject.debuffReflectStacks = 0
	subject.buffProtectStacks = 0
	Util.killTween(subject.attackTween)
	if subject.battleRageAura.visible:
		subject.battleRageAnimation.play("BattleRageEnded")
	subject.battleRageParticles.deactivate()
	subject.battleRageBonusDur = 0.0
	subject.bonusFatigueDamage = 0
	subject.blindingLightActive = false
	subject.meleeSpikesLimit = 1.0
	subject.rangedSpikesLimit = 0.0
	subject.effectSpikesLimit = 0.0
	subject.meleeVampirismLimit = 1.0
	subject.rangedVampirismLimit = 0.0
	subject.empowerDamage = 1.0
	for damageType in DamageSource.Type.values():
		subject.typedDamageFactors[damageType] = 0.0

	subject.poisonDamageSource.critChancePercent = 0
	subject.spikeDamageSource.critChancePercent = 0

static func onTick(subject: Receiver):
	if subject.tickCounter % 2 == 0:
		var regen = subject.getRegeneration()
		if regen > 0:
			subject.heal(regen, Game.EventType.Regeneration)
			subject.buffs[Game.EventType.Regeneration].counter.activate()
	else:
		var poison = subject.getPoison()
		if poison > 0:
			subject.poisonDamageSource.setDamage(poison)
			subject.takeDamage(subject.poisonDamageSource)
			subject.buffs[Game.EventType.Poison].counter.activate()

	subject.tickCounter += 1

static func replayEvent(subject: Receiver, event):
	var origin = event.getOrigin()
	if origin == Game.EventType.Regeneration:
		subject.buffs[Game.EventType.Regeneration].counter.activate()
		subject.spawnLabel(Game.EventType.Health, event.getAmount(), Game.EventType.Regeneration, subject.randHealNumberPos())

	elif origin == Game.EventType.Poison:
		subject.buffs[Game.EventType.Poison].counter.activate()
		subject.spawnLabel(Game.EventType.Poison, event.getParam("damage", 0))

	elif origin == Game.EventType.Fatigue:
		subject.spawnLabel(Game.EventType.Fatigue, event.getParam("damage", 0))

	elif origin == Game.EventType.Spikes:
		subject.spawnLabel(Game.EventType.Spikes, event.getParam("damage", 0))

static func playAttackAnimation(subject: Receiver, distance):
	if subject.attackMovingForward: return

	var curPos = subject.spriteNode.position
	var targetPos = subject.combatDefaultPos + Vector2(distance, 0)
	var duration = (targetPos.x - curPos.x) / subject.attackForwardSpeed * Util.rng.randf_range(0.9, 1.1)
	var backDuration = distance / subject.attackBackwardSpeed * Util.rng.randf_range(0.9, 1.1)
	Util.killTween(subject.attackTween)
	subject.attackTween = subject.create_tween()
	subject.attackTween.tween_property(subject.spriteNode, "position", targetPos, duration)
	subject.attackTween.tween_callback(Callable(subject, "attackMovingBack"))
	subject.attackTween.tween_property(subject.spriteNode, "position", subject.combatDefaultPos, backDuration)
	subject.attackMovingForward = true
	Sound.playSound(Util.pickRandomElement(subject.attackSounds), 0, Util.rng.randf_range(0.8, 1.2))
	if Util.clockTime > subject.attackSoundReadyTime:
		subject.playSound(Game.classResources[subject.characterClass].getAttackSound(), - 3)
		subject.attackSoundReadyTime = Util.clockTime + 0.1

static func playActivateAnimation(subject: Receiver):
	if subject.attackMovingForward: return

	var curHeight = subject.spriteNode.position.y
	var targetHeight = subject.combatDefaultPos.y - subject.activateJumpHeight

	var duration = abs(targetHeight - curHeight) / subject.jumpSpeed * Util.rng.randf_range(0.9, 1.1)
	var backDuration = subject.activateJumpHeight / subject.jumpSpeed * Util.rng.randf_range(0.9, 1.1)
	Util.killTween(subject.attackTween)
	subject.attackTween = subject.create_tween()
	subject.attackTween.tween_property(subject.spriteNode, "position:y", targetHeight, duration)
	subject.attackTween.tween_callback(Callable(subject, "attackMovingBack"))
	subject.attackTween.tween_property(subject.spriteNode, "position:y", subject.combatDefaultPos.y, backDuration)
	subject.attackMovingForward = true

static func takeDamage(subject: Receiver, damageSource: DamageSource, triggerEvent) -> DamageResult:

	var damageRes = DamageResult.new()

	damageSource = DamageSource.new().fromDamageSource(damageSource)
	damageRes.damageSource = damageSource
	damageRes.reset()

	if subject.isDead:
		return damageRes

	var item = null
	if damageSource.origin is Item:
		item = damageSource.origin

	var attackEffectCount = 1

	if item != null:
		attackEffectCount += item.rollDoubleAttackEffect()

	if damageSource.canMiss():
		var accuracy = damageSource.accuracy
		damageRes.hit = subject.accuracyRng.rollPercent(accuracy)
		if damageRes.hit and subject.dodgeStacks > 0:
			subject.changeDodgeStacks( - 1)
			damageRes.hit = false
	else:
		damageRes.hit = true

	var pos = subject.randDmgNumberPos()
	var direction = subject.randDmgNumberDir()

	if item != null and damageSource.isAttack():
		item.preDealDamage_early(damageRes)
		if item.hasPreDealDamageEarlyEffect:
			for i in attackEffectCount:
				item.onPreDealDamage_early(damageRes)

	if damageRes.hit:
		damageRes.damage += damageSource.randDamage()

		if damageSource.hasType(DamageSource.Type.Fatigue):
			damageRes.damage += subject.bonusFatigueDamage

		if damageSource.canCrit():
			var critical = false

			var critChancePercent = damageSource.getCritChancePercent()
			if critChancePercent > 0 and subject.critRng.rollPercent(critChancePercent):
				critical = true

			if not damageRes.critical and item != null and item.getCritTokens() > 0:
				item.useCritToken()
				critical = true

			if not damageRes.critical and subject.opponent.getCritTokens() > 0:
				subject.opponent.useCritToken()
				critical = true

			if critical:
				if subject.critResisted():
					Util.spawnBuffLabel(Game.EventType.CriticalResisted, subject.randBuffLabelPos())
				else:
					damageRes.makeCritical()

		var activeDmgResi = clamp(subject.damageResistance / 100, - 10, 1)
		damageRes.damage = round(damageRes.damage * (1.0 - activeDmgResi))

		if damageRes.damageSource.isAttack():

			damageRes.damage -= subject.damageReduction

		if subject.invulnerable:
			damageRes.damage = 0

		EventBus.emitSignal(subject, "pre_take_damage", [damageRes])

		damageRes.damage -= damageRes.damageReduction

		damageRes.damage = max(0, damageRes.damage)

		if item != null and damageSource.isAttack():
			item.preDealDamage_late(damageRes)
			if item.hasPreDealDamageLateEffect:
				for i in attackEffectCount:
					item.onPreDealDamage_late(damageRes)

		EventBus.emitSignal(subject, "pre_take_damage_late", [damageRes])
		damageRes.healthDamage = damageRes.damage

		if damageSource.canBeBlocked():
			var curBlock = subject.getBlock()
			if damageRes.damage > curBlock:
				damageRes.healthDamage -= curBlock
				subject.loseBlock(curBlock)
			else:
				subject.loseBlock(damageRes.damage)
				damageRes.healthDamage = 0

		subject.curHealth -= damageRes.healthDamage

		if damageRes.wasCriticalHit():
			subject.spawnLabel(Game.EventType.CriticalDamage, damageRes.damage, item, pos, direction)
		elif damageSource.hasType(DamageSource.Type.Fatigue):
			subject.spawnLabel(Game.EventType.Fatigue, damageRes.damage, item, pos, direction)
		elif damageSource.hasType(DamageSource.Type.Poison):
			subject.spawnLabel(Game.EventType.Poison, damageRes.damage, item, pos, direction)
		elif damageSource.hasType(DamageSource.Type.Spikes):
			subject.spawnLabel(Game.EventType.Spikes, damageRes.damage, item, pos, direction)
		else:
			subject.spawnLabel(Game.EventType.DealDamage, damageRes.damage, item, pos, direction)

		if subject.playerId == subject.ID.OPPONENT and damageRes.wasCriticalHit() and damageRes.damage > 300:
			SteamHelper.unlockAchievement("BigCrit")

		if subject.damageAnimation.current_animation != "Poison":
			subject.damageAnimation.stop()
			if damageRes.healthDamage == 0:
				subject.damageAnimation.play("Block")
			elif damageSource.hasType(DamageSource.Type.Fatigue):
				subject.damageAnimation.play("Fatigue")
			else:
				subject.damageAnimation.play("Hit")

			subject.damageAnimation.speed_scale = Util.rng.randf_range(0.9, 1.1)
	else:
		subject.spawnLabel(Game.EventType.MissedAttack, 0, item, pos, direction)

	var event
	if item != null:
		event = Game.combatLog.createEvent_Attack(damageRes, triggerEvent)
		item.dealtDamage(damageRes)
	else:
		event = Game.combatLog.createEvent_Damage(damageRes, subject.opponent.playerId, triggerEvent)

	damageRes.event = event
	EventBus.emitEvent(subject, "character_attacked", event, [damageRes])
	EventBus.emitSignal(subject, "character_damaged", [damageRes.healthDamage, damageRes.event])

	subject.emit_signal("health_changed_ui")

	if (item != null and
		damageSource.isAttack() and
		item.hasDealtDamageEffect):
		for i in attackEffectCount:
			item.onDealtDamage(damageRes)

	if subject.curHealth <= 0:
		subject.death()

	subject.applySpikes(damageRes)

	return damageRes

static func spawnLabel(subject: Receiver, type: int, damage: int, item, pos: Vector2, direction: Vector2):

	var setting = Settings.getVal(Settings.Setting.damage_numbers)

	if setting == Settings.DMG_NR_ALL or setting == Settings.DMG_NR_CHAR:
		if type == Game.EventType.MissedAttack:
			Util.spawnMissLabel(pos, direction * 0.8)
		else:
			Util.spawnNumberLabel(type, pos, direction, damage)

	if item != null and item is Item:
		item.spawnLabel(type, damage)

static func applySpikes(subject: Receiver, damageRes: DamageResult):
	if subject.getSpikes() > 0 and damageRes.canTriggerSpikes():
		var spikesLimit: float
		if damageRes.damageSource.hasType(DamageSource.Type.Ranged):
			spikesLimit = subject.rangedSpikesLimit
		else:
			spikesLimit = subject.meleeSpikesLimit

		if damageRes.damageSource.hasType(DamageSource.Type.Effect):
			spikesLimit = max(subject.effectSpikesLimit, spikesLimit)

		var spikeDam = min(subject.getSpikes(), round(damageRes.damage * spikesLimit))
		if spikeDam > 0:
			subject.spikeDamageSource.setDamage(spikeDam)
			subject.opponent.takeDamage(subject.spikeDamageSource, damageRes.event)
			subject.buffs[Game.EventType.Spikes].counter.activate()

static func applyVampirism(subject: Receiver, damageRes: DamageResult):
	if subject.getVampirism() > 0 and damageRes.canTriggerVampirism():
		var vampLimit: float
		if damageRes.damageSource.hasType(DamageSource.Type.Ranged):
			vampLimit = subject.rangedVampirismLimit
		else:
			vampLimit = subject.meleeVampirismLimit

		var healAmount = min(subject.getVampirism(), round(damageRes.damage * vampLimit))
		if healAmount > 0:
			subject.heal(healAmount, Game.EventType.Vampirism, damageRes.event)
			subject.buffs[Game.EventType.Vampirism].counter.activate()

static func heal(subject: Receiver, amount, origin, triggerEvent):
	amount *= subject.getHealingEfficiency()
	amount = round(amount)

	var missingHealth = subject.getMaxHealth() - subject.curHealth
	var overheal = max(0, amount - missingHealth)
	subject.curHealth += amount
	subject.curHealth = min(subject.curHealth, subject.getMaxHealth())

	subject.emit_signal("health_changed_ui")
	subject.spawnLabel(Game.EventType.Health, amount, origin, subject.randHealNumberPos())

	var event = Game.combatLog.createEvent_Heal(amount, subject.playerId, origin, triggerEvent)

	if origin:
		if origin is Item:
			origin.addMetric(Game.ItemMetrics.Heal, amount)
			origin.addMetric(Game.ItemMetrics.Overheal, overheal)
		else:
			Game.combatLog.snapshotMetric(subject.playerId, Game.ItemMetrics.Heal, origin, amount)
			Game.combatLog.snapshotMetric(subject.playerId, Game.ItemMetrics.Overheal, origin, overheal)

	EventBus.emitEvent(subject, "character_healed", event, [event.getAmount(), event])
	if overheal > 0:
		EventBus.emitSignal(subject, "character_overhealed", [overheal, event])

	if subject.getUnhealing() > 0:

		var unhealing = ceil(amount * subject.getUnhealing() * (1 + subject.typedDamageFactors[DamageSource.Type.Unhealing]))
		if unhealing > 0:
			Game.unhealingDamageSource.setDamage(unhealing)
			subject.opponent.takeDamage(Game.unhealingDamageSource, event)

static func gainStamina(subject: Receiver, amount, item, triggerEvent):

	subject.curStamina += amount

	if not subject.allowStaminaOverflow:
		subject.clampStamina()

	if item != null:
		var event = Game.combatLog.createEvent_Stamina(amount, item, subject.playerId, triggerEvent)
		EventBus.logEvent(event)
		item.staminaChanged(amount, Item.StackChangeType.Added_Player)
		Util.spawnLabelOnItem(Game.EventType.Stamina, item, amount)

static func useStamina(subject: Receiver, amount):
	subject.allowStaminaOverflow = true
	EventBus.emitSignal(subject, "character_pre_use_stamina", [amount])
	subject.allowStaminaOverflow = false

	if subject.curStamina >= amount:
		subject.curStamina = max(subject.curStamina - amount, 0)
		subject.clampStamina()
		EventBus.emitSignal(subject, "character_used_stamina", [amount])

		return subject.StaminaResult.Sufficient
	else:
		subject.clampStamina()

		return subject.StaminaResult.Insufficient

static func loseHealth(subject: Receiver, amount, item, triggerEvent):
	subject.curHealth -= amount
	var pos = subject.randDmgNumberPos()
	var direction = subject.randDmgNumberDir()
	Util.spawnNumberLabel(Game.EventType.LoseHealth, pos, direction, amount)
	var event = null
	if item:
		event = Game.combatLog.createEvent_LoseHealth( - amount, subject.playerId, item, triggerEvent)
		EventBus.emitEvent(subject, "character_damaged", event, [event.getAmount(), event])

	subject.emit_signal("health_changed_ui")

	if subject.curHealth <= 0:
		subject.death()

	return event

static func gainMaxStaminaTemporary(subject: Receiver, amount, item, triggerEvent, filled: bool):
	if amount != 0:
		subject.temporaryMaxStamina += amount
		if filled and amount > 0:
			subject.curStamina += amount
		if item != null:
			var event = Game.combatLog.createEvent_TemporaryMaxStamina(item, amount, triggerEvent)
			EventBus.logEvent(event)
			if filled:
				item.staminaChanged(amount, Item.StackChangeType.Added_Player)
			Util.spawnLabelOnItem(Game.EventType.TemporaryMaxStamina, item, amount)

		subject.emit_signal("max_stamina_changed_ui")

static func levelUp(subject: Receiver):
	var color = Game.classResources[Game.curClass].color

	if Game.curRound == Game.SUBCLASS_ROUND:
		subject.levelUpParticles.amount = 50
	else:
		subject.levelUpParticles.amount = 35

	subject.levelUpParticles.self_modulate = color
	subject.levelUpParticles.activate()

	subject.damageAnimation.play("LevelUp")
	subject.spriteAnimation.stop()
	subject.spriteAnimation.speed_scale = 1.0
	subject.spriteAnimation.play("Jump")

static func makeInvulnerable(subject: Receiver, invuDur, item, triggerEvent):
	subject.invulnerabilityItem = item

	if not subject.invulnerable:
		subject.invulnerabilityTimer.start(invuDur)
		subject.invulnerable = true
		subject.playInvulnerableAnimation(true)
		Sound.playSound(subject.invuSound, 4, Util.randPitch(0.1))
	else:
		Util.changeTimer(subject.invulnerabilityTimer, invuDur)

	var event = Game.combatLog.createEvent_InvulnerableStart(item, invuDur, subject.playerId, triggerEvent)
	EventBus.emitEvent(subject, "character_invulnerable_start", event, [event])
	Game.combatLog.snapshotCharacterStat(subject, subject.Stat.Invulnerable, false, event)
	return event

static func stun(subject: Receiver, duration, item, triggerEvent):

	if subject.stunResisted():
		Util.spawnBuffLabel(Game.EventType.StunResisted, subject.randBuffLabelPos(), duration)
		var event = Game.combatLog.createEvent_StunResist(item, subject.playerId, triggerEvent)
		EventBus.logEvent(event)
	else:
		subject.stunnedDuration = max(subject.stunnedDuration, duration)
		var event = Game.combatLog.createEvent_Stun(item, duration, subject.playerId, triggerEvent)
		EventBus.emitEvent(subject, "character_stunned", event, [event])
		Game.combatLog.snapshotCharacterStat(subject, subject.Stat.Stunned, false, event)
		subject.playStunAnimation()
		Sound.playSound(subject.stunnedSound)

static func changeTypedDamageFactor(subject: Receiver, damageType: int, amount):
	subject.typedDamageFactors[damageType] += amount
	for item in subject.INVENTORY.getItems():
		if item.damageSource != null and item.damageSource.hasType(damageType):
			Game.combatLog.snapshotItemTooltipStat(item, Item.Stat.MinDamage)
			Game.combatLog.snapshotItemTooltipStat(item, Item.Stat.MaxDamage)

	match damageType:
		DamageSource.Type.Melee:
			Game.combatLog.snapshotCharacterStat(subject, subject.Stat.MeleeDmgFactor)
		DamageSource.Type.Ranged:
			Game.combatLog.snapshotCharacterStat(subject, subject.Stat.RangedDmgFactor)
		DamageSource.Type.Effect:
			Game.combatLog.snapshotCharacterStat(subject, subject.Stat.EffectDmgFactor)

static func changeEffectDamageFactor(subject: Receiver, amount):
	subject.typedDamageFactors[DamageSource.Type.Effect] += amount
	subject.typedDamageFactors[DamageSource.Type.Unhealing] += amount
	for item in subject.INVENTORY.getItems():
		if item.damageSource != null and item.damageSource.hasType(DamageSource.Type.Effect):
			Game.combatLog.snapshotItemTooltipStat(item, Item.Stat.MinDamage)
			Game.combatLog.snapshotItemTooltipStat(item, Item.Stat.MaxDamage)
	Game.combatLog.snapshotCharacterStat(subject, subject.Stat.EffectDmgFactor)

static func onSpriteClicked(subject: Receiver):
	if subject.animation.current_animation != "" and Util.isTweenRunning(subject.attackTween): return

	var remainingTime = Util.getRemainingAnimationTime(subject.spriteAnimation)
	if remainingTime > 0.2: return

	subject.spriteAnimation.stop()
	subject.spriteAnimation.speed_scale = Util.rng.randf_range(0.8, 1.4)
	subject.spriteAnimation.play("Jump")

	if not OS.has_feature("crazygames"):
		subject.playSound(Game.classResources[subject.characterClass].getClickedSound(), 0, Util.rng.randf_range(0.9, 1.0))

static func startBattleRage(subject: Receiver, item, duration, triggerEvent, applyBonus):

	var fullDur = duration
	if applyBonus:
		fullDur += subject.battleRageBonusDur
	subject.battleRageTimer.start(fullDur)

	var event = Game.combatLog.createEvent_BattleRageStart(item, fullDur, triggerEvent)
	EventBus.emitEvent(subject, "battle_rage_started", event, [event])
	Game.combatLog.snapshotCharacterStat(subject, subject.Stat.BattleRage, false, event)
	subject.playBattleRageAnimation(true)

static func getStat(subject: Receiver, stat):
	match stat:
		subject.Stat.StaminaRegen:
			return (subject.getStaminaRegeneration() - 1) * 100.0
		subject.Stat.Health:
			return subject.getCurrentHealth()
		subject.Stat.MaxHealth:
			return subject.getTemporaryMaxHealth()
		subject.Stat.Stamina:
			return subject.getCurrentStamina()
		subject.Stat.MaxStamina:
			return subject.getMaxStamina()
		subject.Stat.Stunned:
			return subject.stunnedDuration
		subject.Stat.Invulnerable:
			return subject.invulnerable
		subject.Stat.BattleRage:
			return subject.isBattleRaging()

		subject.Stat.ReflectStacks:
			return subject.debuffReflectStacks
		subject.Stat.DebuffResistStacks:
			return subject.debuffResistStacks
		subject.Stat.CritStacks:
			return subject.getCritTokens()
		subject.Stat.DodgeStacks:
			return subject.dodgeStacks
		subject.Stat.CritResistStacks:
			return subject.critResistStacks
		subject.Stat.CritResistance:
			return subject.critResistance
		subject.Stat.StunResistance:
			return subject.stunResistance
		subject.Stat.HealEfficiency:
			return (subject.getHealingEfficiency() - 1) * 100
		subject.Stat.DamageResistance:
			return subject.damageResistance
		subject.Stat.MeleeDmgFactor:
			return subject.typedDamageFactors[DamageSource.Type.Melee] * 100
		subject.Stat.RangedDmgFactor:
			return subject.typedDamageFactors[DamageSource.Type.Ranged] * 100
		subject.Stat.EffectDmgFactor:
			return subject.typedDamageFactors[DamageSource.Type.Effect] * 100
		subject.Stat.Unhealing:
			return subject.getUnhealing() * 100
		subject.Stat.MaxHealthGain:
			return (subject.temporaryMaxHealthGain - 1.0) * 100
