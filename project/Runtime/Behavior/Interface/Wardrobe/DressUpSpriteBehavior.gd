extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Wardrobe/DressUpSprite.gd")

static func setSkin(subject: Receiver, slot: int, skinId: int):

	var aniTime = subject.character.idleAnimation.current_animation_position

	var style = int(subject.character.isChibi())
	var skin = SkinBook.getSkinFromId(subject.character.getClass(), style, skinId)
	var skinInstance = skin.scene.instantiate()
	skinInstance.hide()
	Game.add_child(skinInstance)
	var skinSlotNodes = subject.searchNodes(slot, skinInstance)
	var oldSlotNodes = subject.searchNodes(slot, subject)

	for node in skinSlotNodes:
		var pathToParent = skinInstance.get_path_to(node.get_parent())
		var path = skinInstance.get_path_to(node)

		var replacement = Node2D.new()
		replacement.name = node.name
		node.replace_by(replacement)
		var toReplace = subject.get_node_or_null(path)

		if toReplace:
			toReplace.replace_by(node)
			oldSlotNodes.erase(toReplace)
			toReplace.queue_free()
		else:

			var newParent = subject.get_node(pathToParent)
			newParent.add_child(node)

	skinInstance.queue_free()
	for leftOverNode in oldSlotNodes:
		leftOverNode.queue_free()

	subject.idleAnimationPlayers.clear()
	subject.findIdleAnis(subject)

	subject.character.idleAnimation.stop()
	subject.character.idleAnimation.play("Idle")
	subject.character.idleAnimation.seek(aniTime)
	subject.syncIdleAnis()

static func findIdleAnis(subject: Receiver, node):
	if node is AnimationPlayer and node.name.ends_with("Idle"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			subject.idleAnimationPlayers.push_back(node)
	for child in node.get_children():
		subject.findIdleAnis(child)

static func syncIdleAnis(subject: Receiver):
	if subject.character.idleAnimation.current_animation == "Idle":
		var aniTime = subject.character.idleAnimation.current_animation_position
		for player in subject.idleAnimationPlayers:

			player.speed_scale = subject.character.idleAnimation.speed_scale
			player.play("Idle")
			player.seek(aniTime)

static func visitNode(subject: Receiver, slot, node):
	if node.is_in_group(Game.slotNames[slot]):
		subject.slotNodes.push_back(node)
	for child in node.get_children():
		subject.visitNode(slot, child)
