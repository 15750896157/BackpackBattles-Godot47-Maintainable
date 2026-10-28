extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Items/Gems/Gem.gd")

static func getGemMode(subject: Receiver):
	if subject.socket != null:
		if subject.getItem().isWeapon():
			return subject.GemMode.Weapon
		else:
			return subject.GemMode.Armor
	else:
		if subject.placed:
			return subject.GemMode.Inventory
		else:
			return subject.GemMode.Inactive

static func addToSocket(subject: Receiver, _socket):
	subject.socket = _socket
	subject.ownerType = subject.Owner.Socket
	subject.socket.onDropGem(subject)
	subject.z_index = 0
	Util.reparentNode(subject, subject.socket)
	subject.occupiedCells.clear()
	if subject.getItem().ownerType == subject.Owner.PlayerInventory:
		CraftingManager.itemAdded(subject)

static func getDescription(subject: Receiver, wrapInColor):
	var descr = subject.getBaseDescription(wrapInColor)
	var colors = [Util.inactiveColor, Util.inactiveColor, Util.inactiveColor]
	var gemMode = subject.getGemMode()
	if gemMode != subject.GemMode.Inactive:
		colors[gemMode] = Util.modifiedColor
	return subject.getModeDescription(descr, colors, true, wrapInColor)
