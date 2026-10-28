extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Wardrobe/Wardrobe.gd")

static func close(subject: Receiver):
	if subject.visible:
		subject.emit_signal("closed")
		subject.animation.play("Close")
		Sound.playSound(subject.openSound, - 6, 1.2)
		Sound.setMuffledSound(false)

static func onSkinIconHovered(subject: Receiver, icon):
	if subject.isOpen:
		for slot in Game.SkinSlot.size():
			var button = subject.getSkinSlotButton(slot, icon.skin.id)
			button.onHover()

static func onSkinIconSelected(subject: Receiver, icon):
	for slot in Game.SkinSlot.size():
		if Game.isSkinUnlocked(slot, icon.skin.id):
			var button = subject.getSkinSlotButton(slot, icon.skin.id)
			button.select()
			subject.onSlotSelected(button)

static func onSlotSelected(subject: Receiver, slotButton):
	var slot = slotButton.slot
	if subject.selectedSkins[slot] != slotButton.skin.id:

		var oldButton = subject.getSkinSlotButton(slot, subject.selectedSkins[slot])
		oldButton.deselect()
		subject.selectedSkins[slot] = slotButton.skin.id
		Game.selectSkin(slot, slotButton.skin.id)
