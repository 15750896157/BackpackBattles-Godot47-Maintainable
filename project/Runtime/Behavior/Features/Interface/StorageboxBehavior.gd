extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Storagebox.gd")

static func _ready(subject: Receiver) -> void :
	Game.STORAGEBOX = subject
	Game.connect("shop_closed", Callable(subject, "onShopClose"))
	Game.connect("shop_opened", Callable(subject, "onShopOpenFinished"))

	Game.connect("returned_to_title", Callable(subject, "deleteItems"))

static func getStorageRect(subject: Receiver):
	if subject.has_meta("art_storage_rect"): return subject.get_meta("art_storage_rect")
	if Expedition.enabled: return Rect2(subject.global_position + Vector2(-218, 8), Vector2(436, 154))
	return Rect2(subject.box.global_position - subject.shape.size * 0.5, subject.shape.size)

static func isHovered(subject: Receiver):
	if Expedition.enabled: return Game.draggedItem != null and subject.getStorageRect().has_point(Game.draggedItem.global_position)
	var pos = Game.draggedItem.global_position
	return subject.getStorageRect().has_point(pos)

static func getItemsAndGemsByDescriptor(subject: Receiver) -> Dictionary:
	var dict = {}
	for item in subject.items:
		Util.dictAppend(dict, item.descriptor, item)
		for gem in item.getGemsNoNull():
			Util.dictAppend(dict, gem.descriptor, gem)
	return dict

static func addItem(subject: Receiver, item):
	if Expedition.enabled and item.has_meta("pve_definition_id"):
		if item not in subject.items: subject.items.append(item)
		return
	subject.items.push_back(item)
	if subject.items.size() >= 30:
		SteamHelper.unlockAchievement("FullStorage")

	subject.emit_signal("item_added", item)

static func getSuggestedPosition(subject: Receiver, itemI):
	if Expedition.enabled: return subject.pve_slot_rect(itemI).get_center()
	if itemI >= subject.suggestedPositions.size(): return subject.center
	return subject.center + subject.suggestedPositions[itemI] * 0.7

static func land(subject: Receiver):
	Sound.playSound(subject.landSound, 0, Util.randPitch(0.1) + 0.1)
	subject.animation.play(str("Landing", Util.rng.randi_range(1, 3)))
	ObjectPool.particleOneShot(subject.dustParticlesScene, subject.dustParticlesPos1)
	ObjectPool.particleOneShot(subject.dustParticlesScene, subject.dustParticlesPos2)
