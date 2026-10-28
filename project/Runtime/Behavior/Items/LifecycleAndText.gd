extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Item.gd")

static func _ready(subject: Receiver) -> void :
	if not subject.pooled:

		if not subject.descriptor:
			subject.descriptor = ItemBook.getDescriptor(subject.name)
			subject.ownerType = subject.Owner.RecipeBook

	if subject.sprite.get_script() != null:
		if subject.sprite is SquishySprite:
			subject.hasSquishySprite = not subject.pooled or subject.ownerType == subject.Owner.Title
		subject.sprite.init()

	if not subject.initialized:
		subject.collisionMap.hide()

		if Game.EDITOR:
			assert (LegacyGrid.used_cells_by_id(subject.collisionMap, subject.Tiles.AffectedDynamic).is_empty())
			assert (LegacyGrid.used_cells_by_id(subject.collisionMap, subject.Tiles.AffectedSecondaryDynamic).is_empty())

		subject.clickArea.show()

		subject.spriteScale = subject.sprite.scale
		subject.sprite.offset = subject.sprite.position / subject.sprite.scale
		subject.sprite.position = Vector2.ZERO
		subject.get_node("Icon/Sockets").position = subject.sprite.offset

		for root in [subject, subject.sprite]:
			for child in root.get_children():
				if child.name.begins_with("SpecificDragParticles"):
					subject.specificDragParticles.push_back(child)

		for node in subject.sprite.get_children():
			if node is GPUParticles2D or node is Sprite2D:
				node.position += subject.sprite.offset

		subject.initSockets()

		subject.empowerEnd()
		subject.baseCooldownOverride = subject.descriptor.cd
		subject.progressMaterial = subject.itemMaterial.duplicate()
		subject.initSpriteMaterial()
		subject.clearSpriteMaterial()

		subject.spritesWithShadows.push_back(subject.sprite)
		for node in Util.getAllChildren(subject.sprite):
			if node.is_in_group("hasShadow"):
				subject.spritesWithShadows.push_back(node)

		for node in subject.spritesWithShadows:
			var shadow = subject.shadowScene.instantiate()
			subject.shadows.push_back(shadow)

			subject.add_child(shadow)
			shadow.texture = node.texture
			shadow.modulate = Color(0, 0, 0, 0.5)
			shadow.z_index = - 1
			shadow.global_scale = subject.sprite.global_scale
			shadow.offset = subject.sprite.offset
			shadow.global_rotation = subject.sprite.global_rotation
			subject.shadowOffset = subject.getShadowOffset()
			shadow.global_position = subject.sprite.global_position + subject.shadowOffset

		subject.collisionShape = subject.get_node_or_null("CollisionShape2D")
		if subject.collisionShape == null:
			subject.collisionShape = subject.get_node("CollisionPolygon2D")

		subject.dragParticles.modulate = Game.rarityColors[subject.getRarity()].lightened(0.3)

		for buff in Game.getStacks():
			subject.buffPowers[buff] = 1.0
			subject.buffAmplificationChances[buff] = 0.0

		subject.cacheCollisionCells()

		subject.affectedExtensionCells = LegacyGrid.used_cells_by_id(subject.collisionMap, subject.Tiles.AffectedExtension)
		for cell in subject.affectedExtensionCells:
			subject.collisionMap.set_cell(0, Vector2i(cell), - 1, Vector2i.ZERO, 0)

		subject.statDisplayOverrides.resize(subject.Stat.size())
		subject.statDisplayOverrides.fill(null)

		subject.itemMetrics.resize(subject.getNumItemMetrics())
		subject.itemMetrics.fill(0)

		subject.initPhysicsMaterial()

		for color in subject.Affected.values():
			subject.currentAffectedItems[color] = {}

		subject.initialized = true

	subject.set_physics_process(false)
	subject.makeNonRigidBody()
	subject.showCooldown(0.0)
	subject.scale = Vector2.ONE
	subject.modulate = Color.WHITE
	subject.rotation = 0
	subject.clickArea.connect("mouse_entered", Callable(subject, "mouseEntered"))
	subject.clickArea.connect("mouse_exited", Callable(subject, "mouseExited"))

	if subject.isOwnable():
		ItemBook.onOwnableItemAdded(subject)
		Game.setItemEditMode(subject)
	elif subject.isOwnedByOpponent():
		ItemBook.onOpponentItemAdded(subject)
		subject.set_process_input(false)

	subject.call_deferred("ready_deferred")

static func ready_deferred(subject: Receiver):

	if not subject.is_inside_tree():
		return

	subject.resetZ()
	subject.averagedPosition = subject.global_position

	if subject.ownerType == subject.Owner.Shop:
		subject.makeGrabbable(true)

	if subject.isOwnable() and subject.has_method("onItemInstantiated"):
		ItemBook.connect("item_instantiated_deferred", Callable(subject, "onItemInstantiated"))

	if not subject.pooled:
		subject.insideRotationNode = Node2D.new()
		subject.insideRotationNode.name = "InsideRotation"
		subject.add_child(subject.insideRotationNode)

static func initPhysicsMaterial(subject: Receiver):
	subject.baseFriction = 0.5
	var baseMass = 1 + subject.getNumCells() * 0.5
	match subject.descriptor.physics:
		subject.Physics.Default:
			subject.mass = baseMass
		subject.Physics.Light:
			subject.mass = baseMass * 0.5
			subject.linear_damp = 0.1
		subject.Physics.Dense:
			subject.gravity_scale = 4.5
			subject.mass = baseMass * 2
		subject.Physics.BouncyDense:
			subject.gravity_scale = 4.5
			subject.mass = baseMass * 2
			subject.baseBounce = 2.0
			subject.frictionTime = 20.0
		subject.Physics.VeryDense:
			subject.gravity_scale = 5.5
			subject.mass = baseMass * 2.5
		subject.Physics.Ice:
			subject.gravity_scale = 4
			subject.mass = baseMass * 2
			subject.baseFriction = 0.0
		subject.Physics.Slime:
			subject.baseBounce = 2.0
			subject.baseFriction = 0.4
			subject.frictionTime = 30.0
			subject.linear_damp = - 0.1
			subject.mass = baseMass
		subject.Physics.Floaty:
			subject.gravity_scale = 1.8
			subject.mass = baseMass * 0.5
			subject.linear_damp = 0.3
		subject.Physics.Ghost:
			subject.gravity_scale = 1.2
			subject.mass = baseMass * 2.0 + 2.0
			subject.linear_damp = 0.7
		subject.Physics.Sand:
			subject.gravity_scale = 4
			subject.mass = baseMass * 1.5
			subject.baseBounce = 0.2
		subject.Physics.Plush:
			subject.gravity_scale = 2.5
			subject.mass = baseMass * 0.75
			subject.baseBounce = 0.2
		subject.Physics.BlackHole:
			subject.gravity_scale = 7
			subject.mass = baseMass * 2.5
			subject.baseBounce = 0.3
			subject.baseFriction = 0.8

	subject.totalWeight = 0.3 + subject.mass * sqrt(subject.getNumCells()) * 0.2

static func getDescription(subject: Receiver, wrapInColor) -> String:
	if subject.pve_is_view(): return Expedition.t(str(subject.pve_definition().get("description_key", "")))
	var descr = subject.descriptor.getDescription()
	if subject.descriptor.requiredItem != null:
		var requiredStr = Util.tra("TOOLTIP_Requires").format({
			"itemName": subject.descriptor.requiredItem.getTranslatedName()
			})
		if descr.begins_with("$t"):
			descr = requiredStr + descr
		else:
			descr = str(requiredStr, "\n\n", descr)

	return subject.insertParameters(descr, wrapInColor)

static func insertParameters(subject: Receiver, descr, wrapInColor):
	if subject.getBaseMinDamage() > 0 and wrapInColor:
		descr = descr.replace("$dam", Util.wrapInColor_fixed(str(subject.descriptor.minDam), Util.paramColor))

	for i in subject.descriptor.extraCds.size() + 1:
		descr = subject.insertParameter(descr, str("cd", i + 1), subject.getModifiedCooldownIndex(i),
			subject.isCooldownModified(), true, wrapInColor)

	descr = subject.insertParameter(descr, "cd", subject.getModifiedCooldown(), subject.isCooldownModified(), true, wrapInColor)
	descr = subject.insertParameter(descr, "chance2", subject.getChance2(), subject.isChance2Modified(), true, wrapInColor)
	descr = subject.insertParameter(descr, "chance", subject.getChance(), subject.isChance1Modified(), true, wrapInColor)
	descr = subject.insertParameter(descr, "shopchance", subject.getShopChance(), subject.StatModified.No, true, wrapInColor)
	descr = subject.insertParameter(descr, "stamina", subject.getStaminaCost(), subject.isStaminaModified(), true, wrapInColor)
	for i in subject.descriptor.params.size():
		descr = subject.insertParameter(descr, "p" + str(i + 1), subject.getP(i), subject.StatModified.No, true, wrapInColor)
	for paramName in subject.descriptor.sortedParamNames:
		descr = subject.insertParameter(descr, "p_" + paramName, subject.getP(paramName), subject.StatModified.No, true, wrapInColor)

	if wrapInColor:
		descr = descr.replace("$block", Util.wrapInColor_fixed(str(subject.getBlock()), Util.paramColor))

	return descr

static func insertParameter(subject: Receiver, descr, paramName, value, modified, checkZero, wrapInColor):
	value = snapped(value, 0.01)
	if value != 0 or not checkZero:
		var replacedString = "$" + paramName
		var startPos = descr.find(replacedString)
		if startPos != - 1:
			var refEndPos = Util.findHighlightEnd(descr, startPos + 1)
			var unit = descr.substr(startPos + replacedString.length(), refEndPos - (startPos + 1) - paramName.length())

			var replacement = str(value) + unit
			if startPos > 0:
				if descr[startPos - 1] == "+":
					replacedString = "+" + replacedString
					replacement = "+" + replacement
				elif descr[startPos - 1] == "-":
					replacedString = "-" + replacedString
					replacement = "-" + replacement

			if wrapInColor:
				replacement = Util.wrapInColor_fixed(replacement, Util.statColors[modified])

			descr = descr.replace(replacedString + unit, replacement)

	return descr

static func getModeDescription(subject: Receiver, text: String, colors: Array, center: bool, wrapInColor: bool):
	var charIndex = 0
	for i in colors.size():
		var dollarPos = text.find("$c[", charIndex)
		var refStartPos = dollarPos + 3
		var refEndPos = ToolTip.findClosingBracket(text, refStartPos)
		var replacement: String
		if i != 0 and center:
			replacement = "\n"

		replacement += Util.substr(text, refStartPos, refEndPos - 1)
		if wrapInColor:
			replacement = Util.wrapInColor(replacement, colors[i])
			if center:
				replacement = str("[center]", replacement, "[/center]\n")

		text = Util.replaceSubstr(text, dollarPos, refEndPos, replacement)
		charIndex = refEndPos

	return text

static func getBagEffect(subject: Receiver, number):
	if subject.pve_is_view(): return "" # The configured description already explains the complete bag effect.
	if not subject.isBag():
		return ""
	else:
		var descr = Util.tra(subject.getName() + "_BAGEFFECT")
		if descr != "":

			descr = subject.insertParameter(descr, "p1", subject.getP(0) * number)
			descr = subject.insertParameter(descr, "p2", subject.getP(1) * number)
			descr = subject.insertParameter(descr, "chance", subject.getChance() * number)
			descr = subject.insertParameters(descr)
		return descr
