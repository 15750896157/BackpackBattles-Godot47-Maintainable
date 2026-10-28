extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/ElectricalCharge.gd")

static func preset(subject: Receiver):
	Game.connect("combat_end", Callable(subject, "onCombatEnded"))
	subject.particles = subject.get_node("GPUParticles2D")
	subject.particlesSpeedScale = subject.particles.speed_scale
	subject.ball = subject.get_node("Sprite2D")
	subject.ball.material = subject.ball.material.duplicate()
	subject.ballMaterial = subject.ball.material
	subject.chargedTileParticles = ObjectPool.instantiate(subject.particleScene)
	subject.chargedTileFrame = subject.chargedTileParticles.get_node("Frame")
	subject.chargedTileAnimation = subject.chargedTileParticles.get_node("Animation")

static func start(subject: Receiver, _item, _cells: Array, _duration: float, replaying: bool):
	subject.duration = _duration
	subject.cells = _cells
	subject.emitterItem = _item

	if not subject.chargedTileParticles.is_inside_tree():
		Game.playerNode.add_child(subject.chargedTileParticles)

		var gradient
		var particleMod
		if (subject.emitterItem.isA(ItemBook.batteryDescriptor) or
			subject.emitterItem.isA(ItemBook.generatorDescriptor) or
			subject.emitterItem.isA(ItemBook.cogBadgeDescriptor)):
			gradient = subject.gradients[0]
			particleMod = subject.modulates[0]
		elif (subject.emitterItem.isA(ItemBook.chargeSplitterDescriptor) or
			subject.emitterItem.isA(ItemBook.contraptronDescriptor)):
			gradient = subject.gradients[1]
			particleMod = subject.modulates[1]
		elif subject.emitterItem.isA(ItemBook.lightningStaffDescriptor):
			gradient = subject.gradients[2]
			particleMod = subject.modulates[2]
		elif subject.emitterItem.isA(ItemBook.manaCrystalDescriptor):
			gradient = subject.gradients[3]
			particleMod = subject.modulates[3]

		subject.ballMaterial.set_shader_parameter("tone_mapping", gradient)
		subject.particles.modulate = particleMod
		subject.chargedTileParticles.modulate = particleMod

		subject.chargedTileParticles.restart()

		subject.particles.speed_scale = subject.particlesSpeedScale

	if replaying:
		subject.chargedTileParticles.emitting = true
	else:
		subject.chargedTileParticles.restart()
		subject.particles.speed_scale = subject.particlesSpeedScale

	subject.chargedTileFrame.self_modulate.a = 1.0

	subject.tween = Util.refreshTween(subject.tween)
	subject.tween.set_parallel()

	var startSize = 1.0
	var endSize = 1.0

	if subject.emitterItem.isA(ItemBook.batteryDescriptor):
		startSize = 0.5
		endSize = 1.5
	elif subject.emitterItem.isA(ItemBook.chargeSplitterDescriptor):
		startSize = 0.5
		endSize = 1.5
	elif subject.emitterItem.isA(ItemBook.lightningStaffDescriptor):
		startSize = 0.8
		endSize = 1.5

	subject.tween.tween_property(subject, "scale", Vector2(endSize, endSize),
		subject.duration).from(Vector2(startSize, startSize))

	var cellCenters = subject.emitterItem.getGlobalPointsForCells(subject.cells)
	subject.inventoryCells = subject.emitterItem.inventory.getCellsForGlobalPositions(cellCenters)

	var halfCellDur = 0.5 * subject.duration / (subject.cells.size() - 1)

	var startPos: Vector2
	var endPos: Vector2
	var delay = 0.0

	for i in subject.cells.size() - 1:

		startPos = (cellCenters[i] + cellCenters[i + 1]) * 0.5

		if i == 0:
			subject.position = startPos
			if not replaying:
				subject.onNewCellEntered(1)
			subject.moveParticlesToCell(cellCenters[1])

		endPos = cellCenters[i + 1]
		subject.tween.tween_property(subject, "position", endPos, halfCellDur).from(startPos).set_delay(delay)
		delay += halfCellDur

		var oldStartPos = startPos
		startPos = endPos
		if i == subject.cells.size() - 2:
			endPos = endPos + endPos - oldStartPos
		else:
			endPos = (cellCenters[i + 1] + cellCenters[i + 2]) * 0.5

		subject.tween.tween_property(subject, "position", endPos, halfCellDur).from(startPos).set_delay(delay)

		delay += halfCellDur

		if not replaying:
			subject.tween.tween_callback(Callable(subject, "onNewCellEntered").bind(i + 2)).set_delay(delay)

		if i < subject.cells.size() - 2:
			subject.tween.tween_callback(Callable(subject, "moveParticlesToCell").bind(cellCenters[i + 2])).set_delay(delay)

	subject.tween.tween_property(subject.particles, "scale",
		Vector2.ONE, subject.FADE_DUR).from(Vector2.ZERO)
	subject.tween.tween_property(subject.ballMaterial, "shader_parameter/intensityFactor",
		subject.MAX_INTENSITY, subject.FADE_DUR).from(subject.MIN_INTENSITY)

	delay = subject.duration - subject.FADE_DUR

	subject.tween.tween_property(subject.particles, "scale",
		Vector2.ZERO, subject.FADE_DUR).from(Vector2.ONE).set_delay(delay)
	subject.tween.tween_property(subject.ballMaterial, "shader_parameter/intensityFactor",
		subject.MIN_INTENSITY, subject.FADE_DUR).from(subject.MAX_INTENSITY).set_delay(delay)

	subject.tween.tween_property(subject.chargedTileFrame, "self_modulate:a",
		0.0, subject.FADE_DUR).from(1.0).set_delay(delay)

	if not replaying:
		subject.tween.tween_callback(Callable(subject, "returnToObjectPool")).set_delay(subject.duration)

static func onNewCellEntered(subject: Receiver, cellIndex: int):
	subject.lastChargedItem = subject.curChargedItem

	if cellIndex == subject.inventoryCells.size():

		subject.curChargedItem = null
	else:
		var curInventoryCell = subject.inventoryCells[cellIndex]
		subject.curChargedItem = subject.emitterItem.inventory.getItemInCell(curInventoryCell)

	subject.emitterItem.onChargeEnteredCell(subject, cellIndex)

	if subject.curChargedItem != subject.lastChargedItem:
		if subject.lastChargedItem != null:
			subject.lastChargedItem.chargeLeft(subject)

		if subject.curChargedItem != null:
			subject.curChargedItem.chargeReceived(subject)
			if subject.curChargedItem.hasOnChargeReceivedEffect:
				var zap = ObjectPool.instantiate(Util.zapScene)
				subject.get_parent().add_child(zap)
				var targetPos = subject.curChargedItem.getGlobalCenter()
				zap.zap(subject.global_position, targetPos, zap.ZapStyle.Small)
