extends Node2D

signal pushed_all_to_storage
signal item_added
signal item_removed
signal storage_cleared

@onready var area = $StorageArea
@onready var box = $StorageArea/CollisionShape2D
@onready var box2 = $StorageArea/CollisionShape2D2
@onready var shape = box.shape
@onready var shape2 = box2.shape

@onready var center = $Center.global_position
@onready var animation = $AnimationPlayer
@onready var dustParticlesPos1 = $DustPosition1
@onready var dustParticlesPos2 = $DustPosition2

const landSound = preload("res://Assets/Sound/Impact.ogg")
const dustParticlesScene = preload("res://Shader/StorageboxLandParticles.tscn")
const suggestedPositions = [
	Vector2.ZERO, Vector2(0, - 200), Vector2(0, 200),
	Vector2( - 200, 0), Vector2(200, 0),
	Vector2(200, - 200), Vector2(200, 200),
	Vector2( - 200, - 200), Vector2( - 200, 200)
]

var items = []

func _ready() -> void :
	load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd")._ready(self)

func getStorageRect():
	return load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd").getStorageRect(self)

func getStorageRect2():
	if Expedition.enabled: return getStorageRect()
	return Rect2(box2.global_position - shape2.size * 0.5, shape2.size)

func hasPosition(pos):
	return getStorageRect().has_point(pos)

func isHovered():
	return load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd").isHovered(self)

func getItems():
	return items

func getItemsAndGems() -> Array:
	var itemsAndGems = items.duplicate()
	for item in items:
		itemsAndGems.append_array(item.getGemsNoNull())
	return itemsAndGems

func getItemsAndGemsByDescriptor() -> Dictionary:
	return load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd").getItemsAndGemsByDescriptor(self)

func addItem(item):
	return load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd").addItem(self, item)

func removeItem(item):
	items.erase(item)

	emit_signal("item_removed", item)

func onShopClose():
	for item in items:
		item.makeNonRigidBody()
		Util.reparentNode(item, self)

func onShopOpenFinished():
	for item in items: item.makeNonRigidBody()
	return

func deleteItems():

	for item in items:

		item.discard()
	items.clear()
	emit_signal("storage_cleared")

func pushAllToStorage():
	Expedition.notice("storage_full")
	return

func pushItemsToStorage(itemList):
	Expedition.notice("storage_full")
	return

func getSuggestedPosition(itemI):
	return load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd").getSuggestedPosition(self, itemI)

func shake(collisionPoint, strong: bool):
	return load("res://Runtime/Behavior/Interface/StorageboxBehavior.gd").shake(self, collisionPoint, strong)

func land():
	return load("res://Runtime/Behavior/Features/Interface/StorageboxBehavior.gd").land(self)

func checkIfItemIsInStorageArea(item):
	return

var pve_slot_root: Node2D
var pve_capacity: int = -1

func pve_slot_rect(index: int) -> Rect2:
	return load("res://Runtime/Behavior/Interface/StorageboxBehavior.gd").pve_slot_rect(self, index)

func pve_refresh_slots(build: Dictionary):
	return load("res://Runtime/Behavior/Interface/StorageboxBehavior.gd").pve_refresh_slots(self, build)

