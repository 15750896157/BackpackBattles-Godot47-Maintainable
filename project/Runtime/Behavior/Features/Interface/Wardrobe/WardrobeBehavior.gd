extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Wardrobe/Wardrobe.gd")

static func close(subject: Receiver):
	if subject.visible and not subject.closing:
		subject.closing = true
		subject.skin_revision += 1
		subject.skin_building = false
		subject.emit_signal("closed")
		subject.animation.play("Close")
		Sound.playSound(subject.openSound, - 6, 1.2)
		Sound.setMuffledSound(false)

static func onSkinIconHovered(subject: Receiver, icon):
	if subject.isOpen and not subject.closing:
		for slot in Game.SkinSlot.size():
			var button = subject.getSkinSlotButton(slot, icon.skin.id)
			if button != null: button.onHover()

static func onSkinIconSelected(subject: Receiver, icon):
	if subject.closing or subject.skin_building: return
	for slot in Game.SkinSlot.size():
		if subject.model.is_unlocked(slot, icon.skin.id):
			var button = subject.getSkinSlotButton(slot, icon.skin.id)
			if button != null:
				button.select()
				subject.onSlotSelected(button)

static func onSlotSelected(subject: Receiver, slotButton):
	var slot = slotButton.slot
	if subject.closing or subject.skin_building or slot >= subject.selectedSkins.size():
		return
	if subject.selectedSkins[slot] == slotButton.skin.id or not subject.model.select(slot, slotButton.skin.id):
		return
	var oldButton = subject.getSkinSlotButton(slot, subject.selectedSkins[slot])
	if oldButton != null: oldButton.deselect()
	subject.selectedSkins[slot] = slotButton.skin.id
