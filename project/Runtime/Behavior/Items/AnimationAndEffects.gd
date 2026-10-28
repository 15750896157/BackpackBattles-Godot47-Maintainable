extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func playActivationAnimation_JumpSquash(subject: Receiver, height, intensity):
	subject.shadowTween = Util.refreshTween(subject.shadowTween)
	subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var startPos = subject.sprite.global_position.y

	var longScale = 1.0 + intensity
	var shortScale = 1.0 / longScale
	var scaling: Vector2
	if subject.faceDirection == subject.FaceDirection.UP or subject.faceDirection == subject.FaceDirection.DOWN:
		scaling = Vector2(shortScale, longScale)
	else:
		scaling = Vector2(longScale, shortScale)

	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale * scaling, 0.1).set_ease(Tween.EASE_IN_OUT)
	subject.shadowTween.parallel().tween_property(subject.sprite, "global_position:y",
		startPos - height, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	subject.shadowTween.tween_property(subject.sprite, subject.getScaleProp(), subject.spriteScale, 0.2).set_ease(Tween.EASE_IN_OUT).set_delay(0.05)
	subject.shadowTween.parallel().tween_property(subject.sprite, "global_position:y",
		startPos, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

static func playActivationAnimation(subject: Receiver, aniType, consume: bool):
	if subject.pve_is_view():
		preload("res://PvE/Art/ItemMotion.gd").activate(subject,aniType,consume)
		return

	subject.resetSprite()

	if aniType == subject.ActivationAni.Jump:
		subject.animation.play("Activate")
		subject.playActivationAnimation_Jump(40)

	elif aniType == subject.ActivationAni.SquishyJump:
		subject.animation.play("Activate")
		subject.playActivationAnimation_JumpSquash(40, 0.1)

	elif aniType == subject.ActivationAni.VerySquishyJump:
		subject.animation.play("Activate")
		subject.playActivationAnimation_JumpSquash(40, 0.2)

	elif aniType == subject.ActivationAni.Slash:
		subject.animation.play("Activate_Slash")

	elif aniType == subject.ActivationAni.Stab:
		subject.animation.play("Activate_Stab")

	elif aniType == subject.ActivationAni.ReverseStab:
		subject.animation.play("Activate_Reverse_Stab")

	elif aniType == subject.ActivationAni.Bonk:
		subject.animation.play("Activate_Bonk")

	elif aniType == subject.ActivationAni.ReverseBonk:
		subject.animation.play("Activate_ReverseBonk")

	elif aniType == subject.ActivationAni.Sweep:
		subject.animation.play("Activate_Sweep")

	elif aniType == subject.ActivationAni.Block:
		subject.animation.play("Activate")
		subject.playActivationAnimation_Jump(30, 1.3)
		subject.shadowTween.set_speed_scale(1.2)

	elif aniType == subject.ActivationAni.Chop:
		subject.animation.play("Activate_Chop")

	elif aniType == subject.ActivationAni.Wave:
		subject.animation.play("Activate_Wave")

	elif aniType == subject.ActivationAni.Throw:
		subject.animation.play("Activate_Throw")

	elif aniType == subject.ActivationAni.Scale:
		subject.animation.play("Activate")
		subject.playActivationAnimation_Scale(1.5)

	elif aniType == subject.ActivationAni.Squish:
		subject.animation.play("Activate")

		if subject.hasSquishySprite:
			subject.sprite.addMomentum(0.1)
		else:
			subject.shadowTween = Util.refreshTween(subject.shadowTween)
			subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			subject.shadowTween.tween_property(subject.sprite, "scale",
				Vector2(subject.spriteScale.x * 1.2, subject.spriteScale.y * 0.8),
				0.07).set_ease(Tween.EASE_IN_OUT)
			subject.shadowTween.tween_property(subject.sprite, "scale",
				Vector2(subject.spriteScale.x * 0.8, subject.spriteScale.y * 1.2),
				0.2).set_ease(Tween.EASE_IN_OUT)
			subject.shadowTween.tween_property(subject.sprite, "scale",
				Vector2(subject.spriteScale.x * 1.1, subject.spriteScale.y * 0.9),
				0.13).set_ease(Tween.EASE_IN_OUT)
			subject.shadowTween.tween_property(subject.sprite, "scale",
				subject.spriteScale, 0.1).set_ease(Tween.EASE_IN_OUT)

	elif aniType == subject.ActivationAni.Potion:
		subject.animation.play("Activate_Potion")

	elif aniType == subject.ActivationAni.Hiss:
		subject.animation.play("Activate_Snake")
		subject.shadowTween = Util.refreshTween(subject.shadowTween)
		subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			Vector2(subject.spriteScale.x, subject.spriteScale.y * 0.8),
			0.1).set_ease(Tween.EASE_OUT)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			Vector2(subject.spriteScale.x, subject.spriteScale.y * 1.2),
			0.18).set_ease(Tween.EASE_IN).set_delay(0.08)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			subject.spriteScale,
			0.14).set_ease(Tween.EASE_IN_OUT)

	elif aniType == subject.ActivationAni.Spin:
		subject.animation.play("Activate_Spin")

	elif aniType == subject.ActivationAni.Tackle:
		subject.animation.play("Activate_Tackle")

	elif aniType == subject.ActivationAni.DoubleSlash:
		subject.animation.play("Activate_DoubleSlash")

	elif aniType == subject.ActivationAni.Struggle:
		subject.animation.play("Activate_Struggle")
		subject.playActivationAnimation_Jump(30)

	elif aniType == subject.ActivationAni.Shoot:
		subject.animation.play("Activate_Shoot")
		subject.shadowTween = Util.refreshTween(subject.shadowTween)
		subject.shadowTween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			Vector2(subject.spriteScale.x * 1.3, subject.spriteScale.y * 0.8),
			0.2).set_ease(Tween.EASE_IN_OUT)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			Vector2(subject.spriteScale.x * 0.8, subject.spriteScale.y * 1.0),
			0.1).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			Vector2(subject.spriteScale.x * 1.1, subject.spriteScale.y * 0.9),
			0.05).set_ease(Tween.EASE_IN_OUT)
		subject.shadowTween.tween_property(subject.sprite, "scale",
			subject.spriteScale, 0.1).set_ease(Tween.EASE_IN_OUT)

	elif aniType == subject.ActivationAni.Flash:
		subject.animation.play("Activate")

	if consume:
		subject.animation.queue("Consume")

static func activate(subject: Receiver, damageRes, playCombatAni, consume, animationOverride):

	if subject.dragged: return
	if Util.isTweenRunning(subject.movebackTween): return

	if Util.time > subject.lastActivationTime:
		subject.activationsThisFrame = 1
		subject.lastActivationTime = Util.time
	else:
		subject.activationsThisFrame += 1
		if subject.activationsThisFrame > 3: return

	var event = null

	if not Game.fightEnded:
		if not subject.isBag():
			event = Game.combatLog.createEvent_Activation(subject)
			EventBus.emitEvent(subject, "activated", event, [event])
			subject.addMetric(Game.ItemMetrics.Activations)
		if subject.hasCooldown():
			Game.combatLog.snapshotItemTooltipStat(subject, subject.Stat.Cooldown, null,
				false, event)

	if not subject.isBag():
		subject.z_index = 3
		Util.callDelayed(subject, "resetZ", 0.4)

	if animationOverride != null:
		subject.playActivationAnimation(animationOverride, consume)
	subject.playActivationSound()

	if playCombatAni:
		if damageRes and not damageRes.hasHit():
			subject.playAnimation(false)
		else:
			subject.playAnimation()

	if damageRes:
		subject.character().playActivateAnimation()

	return event

static func activateFromEvent(subject: Receiver, event):

	if event.type == Game.EventType.Activation:
		if not subject.isBag():
			subject.z_index = 2
			Util.callDelayed(subject, "resetZ", 0.5)
		subject.playActivationAnimation()
		subject.playActivationSound()

	elif Game.isStack(event.type):
		var appliedToOpponent = (event.target != subject.character().playerId)
		var amount = event.getAmount()
		var target = subject.opponent() if appliedToOpponent else subject.character()
		if event.getParam("resisted", false):
			Util.spawnResistedLabel(event.type, target.randBuffLabelPos(), amount)
		elif event.getParam("protected", false):
			Util.spawnProtectedLabel(event.type, subject.character().randBuffLabelPos(), amount)
		elif event.getParam("reflected", false):
			target = subject.character() if appliedToOpponent else subject.opponent()
			Util.spawnReflectLabel(event.type, target.randBuffLabelPos(), amount)
		else:
			Util.spawnBuffLabel_item(event.type, subject, amount, appliedToOpponent)

	elif event.type == Game.EventType.DealDamage:
		subject.character().playAttackAnimation()
		var damage = event.getParam("damage", 0)
		subject.opponent().spawnLabel(event.type, damage, subject)
		subject.opponent().damageAnimation.play("Hit")
		subject.playAnimation()

	elif event.type == Game.EventType.CriticalDamage:
		subject.character().playAttackAnimation()
		var damage = event.getParam("damage", 0)
		subject.opponent().spawnLabel(event.type, damage, subject)
		subject.opponent().damageAnimation.play("Hit")
		subject.playAnimation()

	elif event.type == Game.EventType.MissedAttack:
		subject.character().playAttackAnimation()
		subject.opponent().spawnLabel(event.type, 0, subject)
		subject.playAnimation(false)

	elif event.type == Game.EventType.OutofStamina:
		subject.playOutOfStaminaAnimation()

	elif event.type == Game.EventType.Health:
		var healAmount = event.getAmount()
		subject.character().spawnLabel(event.type, healAmount, subject, subject.character().randHealNumberPos())

	elif event.type == Game.EventType.LoseHealth:
		var lostHealth = - event.getAmount()
		subject.character().spawnLabel(event.type, lostHealth, subject)

	elif (event.type in [Game.EventType.Stamina,
		Game.EventType.TemporaryMaxStamina]):

		var amount = event.getParam("stamina", 0)
		subject.spawnLabel_other(event.type, amount)

	elif event.type == Game.EventType.TemporaryMaxHealth:
		var amount = event.getAmount()
		subject.spawnLabel_other(event.type, amount)

static func getStat(subject: Receiver, stat):
	match stat:
		subject.Stat.MaxDamage:
			if subject.getBaseMaxDamage() > 0:
				return subject.getMaxDamage()
			else:
				return 0
		subject.Stat.MinDamage:
			if subject.getBaseMinDamage() > 0:
				return subject.getMinDamage()
			else:
				return 0
		subject.Stat.Accuracy:
			return subject.getAccuracy()
		subject.Stat.CritChance:
			return subject.getCritChancePercent()
		subject.Stat.Speed:
			return subject.getSpeed()
		subject.Stat.Cooldown:
			return subject.getCooldownEncoded()
		subject.Stat.StaminaCost:
			return subject.getStaminaCost()
		subject.Stat.Chance:
			return subject.getChance()
		subject.Stat.Chance2:
			return subject.getChance2()
		subject.Stat.BaseCooldown:
			return subject.getCooldown()

static func stackChanged(subject: Receiver, stackType: int, amount: int, onPlayer: bool, used: bool):
	var changeType: int
	if amount > 0:
		changeType = subject.StackChangeType.Added_Player
	else:
		if used:
			changeType = subject.StackChangeType.Used_Player
		else:
			changeType = subject.StackChangeType.Removed_Player

	if not onPlayer:
		changeType += 1

	var index = subject.getStackMetricIndex(changeType, stackType)
	var playerId = 0 if onPlayer else 1
	subject.addMetric(index, abs(amount), playerId, true)

static func giveBlock(subject: Receiver, amount, canTriggerEffects, triggerEvent):
	if amount > 0:
		var event = subject.giveStacks(subject.character(), Game.EventType.Block, amount, triggerEvent)
		if event != null:
			if canTriggerEffects:
				EventBus.emitSignal(subject, "gave_block", [event.getAmount(), event])
			else:
				EventBus.logEvent(event)
			return event
	return null

static func giveMana_capped(subject: Receiver, amount, maximum, triggerEvent):
	amount = round(amount * subject.buffPowers[Game.EventType.Mana])
	var curMana = subject.character().getMana()
	if maximum > curMana:
		var missingMana = maximum - curMana
		var manaGiven = min(amount, missingMana)
		subject.character().gainMana(manaGiven, subject, triggerEvent)
		return amount - manaGiven
	else:
		return amount

static func sendCharge(subject: Receiver, durPerTile: float, cells: Array, speedFactor: float, event):
	var chargeDuration = durPerTile * (cells.size() - 1)
	var charge = ObjectPool.instantiate(Game.electricalChargeScene)
	Game.playerNode.add_child(charge)
	charge.start(subject, cells, chargeDuration / speedFactor)
	charge.logEvent(event)
	Sound.playSound(subject.chargeSound, Util.rng.randf_range( - 12, - 5), Util.randPitch(0.3))

static func changeChargedItemStat(subject: Receiver, charge, cellIndex, flatVal, valPerTile):

	var previousVal = flatVal + (cellIndex - 2) * valPerTile
	var newVal = previousVal + valPerTile

	if charge.lastChargedItem != null:
		if charge.curChargedItem == null:
			subject.me.chargedItemStatChange(charge.lastChargedItem, - previousVal)
		elif charge.curChargedItem == charge.lastChargedItem:
			subject.me.chargedItemStatChange(charge.curChargedItem, valPerTile)
		else:
			subject.me.chargedItemStatChange(charge.lastChargedItem, - previousVal)
			subject.me.chargedItemStatChange(charge.curChargedItem, newVal)

	elif charge.curChargedItem != null:
		subject.me.chargedItemStatChange(charge.curChargedItem, newVal)

static func getSizeInCells(subject: Receiver) -> Vector2:
	var topLeft = Vector2(100, 100)
	var bottomRight = Vector2( - 100, - 100)
	var cells = subject.getCollisionCells()
	if cells.is_empty():
		return Vector2.ZERO

	for cell in cells:
		if cell.x < topLeft.x:
			topLeft.x = cell.x
		if cell.y < topLeft.y:
			topLeft.y = cell.y

		if cell.x > bottomRight.x:
			bottomRight.x = cell.x
		if cell.y > bottomRight.y:
			bottomRight.y = cell.y

	return bottomRight - topLeft + Vector2(1, 1)

static func initSpriteMaterial(subject: Receiver):
	if subject.sprite.texture is AtlasTexture:
		var atlasTranslation = subject.sprite.texture.region.position
		var subTexSize = subject.sprite.texture.region.size
		var atlasSize = subject.sprite.texture.atlas.get_size()
		subject.progressMaterial.set_shader_parameter("atlasTranslation", atlasTranslation / atlasSize)
		subject.progressMaterial.set_shader_parameter("atlasScaling", subTexSize / atlasSize)
	else:

		subject.progressMaterial.set_shader_parameter("atlasTranslation", Vector2.ZERO)
		subject.progressMaterial.set_shader_parameter("atlasScaling", Vector2.ONE)

static func updateShaderRotation(subject: Receiver):
	if subject.nonRotatedProgress != 0:
		if not subject.sprite.material:
			subject.giveProgressMaterial()
		subject.sprite.material.set_shader_parameter("direction", Vector2.DOWN.rotated( - subject.global_rotation))
		subject.showCooldown(subject.nonRotatedProgress)
		var size = subject.getSizeInCells()
		if size.x > 0 and size.y > 0:
			var scaling = Vector2(1.0, 0.8).rotated( - subject.global_rotation)
			subject.sprite.material.set_shader_parameter("scale", size * scaling)

			var rotatedSize = size.rotated( - subject.global_rotation)

			var thickness = 0.1 / abs(rotatedSize.y)
			subject.sprite.material.set_shader_parameter("thickness", thickness)

static func showCooldownSmooth(subject: Receiver, progress: float, fill: bool):
	if not subject.canCancelShaderTween:
		return

	Util.killTween(subject.shaderTween)
	subject.shaderTween = subject.create_tween()

	if fill:
		subject.canCancelShaderTween = false
		subject.shaderTween.tween_method(Callable(subject, "showCooldown"), subject.nonRotatedProgress, 1.0, 0.1)
		subject.shaderTween.tween_callback(Callable(subject, "allowCancelShaderTween"))
		subject.shaderTween.tween_method(Callable(subject, "showCooldown"), 0.0, progress, 0.1)
	else:
		subject.shaderTween.tween_method(Callable(subject, "showCooldown"), subject.nonRotatedProgress, progress, 0.2)

static func createAnimation(subject: Receiver):
	var ani = ObjectPool.instantiate(subject.descriptor.animationScene)
	Game.combatAnimationsNode.add_child(ani)

	if subject.ownerType != subject.Owner.Opponent:
		ani.scale.x = 1
	else:
		ani.scale.x = - 1

	if ani.showOnSelf:
		ani.position = subject.character().position
		ani.scale.x *= - 1
	else:
		ani.position = subject.opponent().position

	return ani
