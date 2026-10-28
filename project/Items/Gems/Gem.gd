extends Item
class_name Gem

var particlesScene = load("res://Items/Animations/SocketParticles.tscn")
var dragParticlesScene = load("res://Items/Gems/GemDragParticles.tscn")

@onready var socketDetectionArea = $SocketDetectionArea
@onready var gemAnimation = $GemAnimation

var hoveredSocket: Socket = null
var socket: Socket = null
var movebackSocket: Socket = null
var dropTween
var gemPower = 1.0

enum GemMode{
	Weapon = 0,
	Armor = 1,
	Inventory = 2,
	Inactive = 3,
}

func _ready() -> void :
	super._ready()
	gemAnimation.advance(Util.rng.randf_range(0, 10))
	if descriptor.gateItem == ItemBook.boxOfRichesDescriptor:
		if specificDragParticles.is_empty():
			var particles = dragParticlesScene.instantiate()
			sprite.add_child(particles)
			particles.amount = 3 + descriptor.rarity
			particles.self_modulate = self.gemColor
			specificDragParticles.push_back(particles)

func isGem():
	return true

func isOwnable() -> bool:
	if socket != null:
		return socket.getItem().isOwnable()
	else:
		return super.isOwnable()

func isOwnedByOpponent() -> bool:
	if socket != null:
		return socket.getItem().isOwnedByOpponent()
	else:
		return super.isOwnedByOpponent()

func getEffectiveOwnerType() -> int:
	if socket != null:
		return socket.getItem().getEffectiveOwnerType()
	else:
		return super.getEffectiveOwnerType()

func getInventory():
	if socket != null:
		return socket.getItem().getInventory()
	else:
		return super.getInventory()

func getItem():
	if socket != null:
		return socket.getItem()
	else:
		return null

func isPlaced() -> bool:
	if socket != null:
		return socket.getItem().isPlaced()
	else:
		return placed

func isInInventory() -> bool:
	if socket != null:
		return socket.getItem().isInInventory()
	else:
		return super.isInInventory()

func getGemMode():
	return load("res://Runtime/Behavior/Features/Items/Gems/GemBehavior.gd").getGemMode(self)

func getGemPower() -> float:
	return max(0.0, gemPower)

func changeGemPower(amount: float):
	gemPower += amount

func getHoverPriority():
	if dragged: return DRAG_PRIORITY
	else: return 1

func character():
	if getGemMode() == GemMode.Inactive:
		return Game.PLAYER
	elif getGemMode() == GemMode.Inventory:
		return super.character()
	else:
		return getItem().character()

func _process(_delta):
	super._process(_delta)
	if dragged:

		if not draggedInsideItems.is_empty():
			return

		var previousSocket: Socket = hoveredSocket

		var sockets = []
		for area in socketDetectionArea.get_overlapping_areas():
			var s = area.get_parent()
			if s.item.visible:
				sockets.push_back(s)

		if sockets.is_empty():
			hoveredSocket = null
			if previousSocket == null:
				affectedCellsActive = true
		else:
			var closestSocket = null
			var closestDist = INF
			for s in sockets:
				if s.isAvailable():
					var dist = (s.global_position - global_position).length_squared()
					if dist < closestDist:
						closestSocket = s
						closestDist = dist

			if closestSocket:
				hoveredSocket = closestSocket
				affectedCellsActive = false

		if hoveredSocket != previousSocket:
			if previousSocket != null:
				previousSocket.onHoverEndWithGem()

			if hoveredSocket != null:
				hoveredSocket.onHoverWithGem()

func previewCellCollision():
	if ( not hoveredSocket and
		( not movebackSocket or Util.frameCounter > pickupFrame + 1)):
		super.previewCellCollision()

func gainFocus():
	if not canGainFocus(): return

	if draggedInsideItems.is_empty():
		Game.showSockets()
	super.gainFocus()

func loseFocus():
	if not focus: return
	super.loseFocus()
	if not Game.draggedItem:
		Game.hideSockets()

var dropPosition
var dropRotation
var quantizedRotation

func prepareLerpToSocket():
	dropPosition = global_position
	dropRotation = global_rotation
	quantizedRotation = snapped(rotation, PI * 0.5)

const socketSound = preload("res://Assets/Sound/Hammer3.wav")

func drop() -> int:
	dragged = false

	Game.hideSockets()
	if hoveredSocket != null:
		Sound.playSound(socketSound, - 5)

		var hotswap = hoveredSocket.getGem()
		addToSocket(hoveredSocket)
		placedByPlayer = true
		prepareLerpToSocket()

		killDropTween()
		dropTween = create_tween()
		dropTween.tween_method(Callable(self, "lerpToSocket"), 0.0, 1.0, 0.1)

		sameOrientationAsPickup = (hoveredSocket == movebackSocket)

		hoveredSocket = null
		movebackSocket = null
		if hotswap:
			return DropResult.SocketHotswap
		else:
			return DropResult.Socketed
	else:
		var res = super.drop()
		if wasAddedToInventory(res):
			movebackSocket = null
		return res

func lerpToSocket(interpolationPoint: float):
	global_position = lerp(dropPosition, socket.global_position, interpolationPoint)
	var targetRotation = socket.global_rotation + quantizedRotation
	global_rotation = lerp_angle(dropRotation, targetRotation, interpolationPoint)

func pickup(pickupType = PickupType.Grabbed):
	super.pickup(pickupType)

	if socket != null:
		killDropTween()
		movebackSocket = socket
		hoveredSocket = socket
		Util.reparentNode(self, Game.playerNode)
		if socket.getItem().ownerType == Owner.PlayerStorageBox:
			setFaceDirection(FaceDirection.UP)
		else:
			faceDirection = getGlobalFaceDirection()

		socket.onPickupGem()

func addToSocket(_socket):
	return load("res://Runtime/Behavior/Features/Items/Gems/GemBehavior.gd").addToSocket(self, _socket)

func unsocket():
	killDropTween()
	Util.reparentNode(self, Game.playerNode)
	var s = socket
	socket.onPickupGem()
	s.hideSocket()

func removeFromSocket():
	if not fusing and canCombine():
		CraftingManager.itemRemoved(self)
	socket = null

func killDropTween():
	Util.killTween(dropTween)
	clickArea.show()
	dropTween = null

func returnToSocket(movebackDur = 0.1):
	return load("res://Runtime/Behavior/Items/Gems/GemBehavior.gd").returnToSocket(self, movebackDur)

func hasCooldown() -> bool:
	var gemMode = getGemMode()
	return ((gemMode == GemMode.Inventory or
				gemMode == GemMode.Inactive) and
				super.hasCooldown())

func miniActivate():
	super.miniActivate()
	playActivationAnimation_Scale(1.5)

func prepareInventory():
	pass

func prepareWeapon():
	pass

func prepareArmor():
	pass

func onPrepare():

	match getGemMode():
		GemMode.Inventory:
			prepareInventory()
		GemMode.Weapon:
			prepareWeapon()
		GemMode.Armor:
			prepareArmor()

func combatStartInventory():
	pass

func combatStartWeapon():
	pass

func combatStartArmor():
	pass

func combatStart():
	super.combatStart()
	iterationCooldown = adjustCooldown()
	triggerTime = iterationCooldown

	match getGemMode():
		GemMode.Inventory:
			combatStartInventory()
		GemMode.Weapon:
			combatStartWeapon()
		GemMode.Armor:
			combatStartArmor()

func combatEndInventory():
	pass

func combatEndWeapon():
	pass

func combatEndArmor():
	pass

func combatEnd():
	super.combatEnd()
	match getGemMode():
		GemMode.Inventory:
			combatEndInventory()
		GemMode.Weapon:
			combatEndWeapon()
		GemMode.Armor:
			combatEndArmor()

func shopEntered(craft: bool):
	super.shopEntered(craft)
	gemPower = 1.0

func getBaseDescription(wrapInColor = true) -> String:
	return super.getDescription(wrapInColor)

func getDescription(wrapInColor = true):
	return load("res://Runtime/Behavior/Features/Items/Gems/GemBehavior.gd").getDescription(self, wrapInColor)

func onHotSwapHoverWithGem():
	gemAnimation.play("HotSwapHover")

func onHotSwapHoverWithGemEnd():
	gemAnimation.play("Sparkle")

func createGemParticles():
	var particles = ObjectPool.particleOneShot(particlesScene, self)
	particles.modulate = self.gemColor
	particles.amount = 5 + 2 * getRarity()

func canPreviewFusions():
	if socket:
		return socket.getItem().canPreviewFusions()
	else:
		return super.canPreviewFusions()

func canModifyChance() -> bool:
	return false

func getNeighborItemsAndGems():
	if socket:
		if getItem().ownerType == Owner.PlayerStorageBox:
			return []

		var neighbors = [getItem()]
		neighbors.append_array(getItem().getNeighborItemsAndGems())
		neighbors.erase(self)
		return neighbors
	else:
		return super.getNeighborItemsAndGems()

func canCombine() -> bool:
	if socket:
		return true
	else:
		return super.canCombine()

func shift(direction: Vector2):
	if not socket:
		super.shift(direction)

func isMovingBack() -> bool:
	if socket:
		return getItem().isMovingBack() or super.isMovingBack() or Util.isTweenRunning(dropTween)
	else:
		return super.isMovingBack()

func addToStorageBox(addImpulse = true, tweenBouncyness: bool = true,
	checkCollisions = true, targetPos = global_position, speed = 1.0, secondCheck = false):
	if socket:
		var s = socket
		super.addToStorageBox(addImpulse, tweenBouncyness,
			checkCollisions, targetPos, speed, secondCheck)
		s.onPickupGem()
		s.hideSocket()
	else:
		super.addToStorageBox(addImpulse, tweenBouncyness,
			checkCollisions, targetPos, speed, secondCheck)

func discard(discardGems = true):
	super.discard(discardGems)
	if socket != null:
		socket.gem = null
		socket.hideSocket()
		socket = null
		movebackSocket = null
