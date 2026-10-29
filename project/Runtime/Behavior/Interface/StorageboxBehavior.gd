extends RefCounted
## Domain behavior. Scene state and overridable API remain on the typed subject.
const Receiver = preload("res://Interface/Storagebox.gd")

static func shake(subject: Receiver, collisionPoint, strong: bool):
	if collisionPoint.y > 980:
		if strong:
			subject.animation.play("ShakeCenterStrong", 0.1)
		else:
			subject.animation.play("ShakeCenter", 0.1)
	elif collisionPoint.x < 1000:
		if strong:
			subject.animation.play("ShakeLeftStrong", 0.1)
		else:
			subject.animation.play("ShakeLeft", 0.1)
	else:
		if strong:
			subject.animation.play("ShakeRightStrong", 0.1)
		else:
			subject.animation.play("ShakeRight", 0.1)

static func pve_slot_rect(subject: Receiver, index: int) -> Rect2:
	var capacity = int(Expedition.flow.run.get("build", {}).get("storage_capacity", 2))
	var area_rect = subject.getStorageRect()
	var width = area_rect.size.x / float(capacity)
	return Rect2(area_rect.position + Vector2(width * clampi(index, 0, capacity - 1) + 5, 4), Vector2(width - 10, area_rect.size.y - 8))

static func pve_refresh_slots(subject: Receiver, build: Dictionary):
	var capacity = int(build.storage_capacity)
	# Keep the original localized chest caption above its fixed slots, leaving
	# the shared bottom tutorial band free and avoiding the stored icon bounds.
	var caption: Label = subject.get_node("StorageShakeButton/Storagebox/Label")
	caption.modulate.a = 0.0
	caption.global_position = subject.getStorageRect().position + Vector2(0, -31)
	caption.size = Vector2(subject.getStorageRect().size.x, 28)
	caption.add_theme_font_override("font", Expedition.ui_font)
	caption.add_theme_font_size_override("font_size", 22)
	if subject.pve_slot_root == null:
		subject.pve_slot_root = Node2D.new()
		subject.pve_slot_root.name = "FixedStorageSlots"
		subject.add_child(subject.pve_slot_root)
	if subject.has_meta("art_storage_rect"):
		subject.pve_slot_root.top_level = true
		subject.pve_slot_root.global_position = Vector2.ZERO
		subject.pve_slot_root.z_as_relative = false
		subject.pve_slot_root.z_index = Util.getGlobalZ(subject)
	subject.pve_slot_root.visible = Game.state == Game.State.Shop
	if capacity == subject.pve_capacity: return
	subject.pve_capacity = capacity
	for child in subject.pve_slot_root.get_children(): child.queue_free()
	for index in capacity:
		var rect = subject.pve_slot_rect(index)
		var slot = Sprite2D.new()
		slot.texture = load("res://Art/Supplied20261028/ui/cell.png")
		slot.position = rect.get_center() if subject.has_meta("art_storage_rect") else subject.to_local(rect.get_center())
		slot.scale = Vector2.ONE * minf(rect.size.x / slot.texture.get_width(), rect.size.y / slot.texture.get_height())
		slot.modulate = Color(1.0, 0.95, 0.85, 0.32)
		subject.pve_slot_root.add_child(slot)
		var text = Label.new()
		text.text = str(index + 1)
		text.position = (rect.position if subject.has_meta("art_storage_rect") else subject.to_local(rect.position)) + Vector2(8, 3)
		if subject.has_meta("art_storage_rect"): text.position = Vector2(rect.get_center().x - 14, rect.position.y + 4)
		text.size = Vector2(28, 26)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.z_index = 10
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_override("font", Expedition.ui_font)
		text.add_theme_font_size_override("font_size", 18)
		text.add_theme_color_override("font_color", Color("fff3d9"))
		text.add_theme_color_override("font_outline_color", Color("3f2a18"))
		text.add_theme_constant_override("outline_size", 3)
		subject.pve_slot_root.add_child(text)
