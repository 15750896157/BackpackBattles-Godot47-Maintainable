extends RefCounted
const ROOT = "res://Art/Polish20261022/"
static func key_for(cells: Array) -> String:
	var bounds = Vector2i.ZERO
	for cell in cells: bounds = bounds.max(Vector2i(cell)+Vector2i.ONE)
	if cells.size() == 9 and bounds == Vector2i(3,3): return "bag9"
	if cells.size() == 4 and bounds == Vector2i(2,2): return "bag4"
	if cells.size() == 6 and bounds == Vector2i(3,2): return "bag6"
	if cells.size() == 6 and bounds == Vector2i(2,3): return "bag6_vertical"
	if cells.size() == 2 and bounds == Vector2i(1,2): return "bag2"
	return ""

static func apply(item, cells: Array, anchor: Vector2, size: Vector2, shop_view: bool, storage_view: bool):
	if not item.isBag(): return
	var key = key_for(cells)
	var id=str(item.get_meta("pve_definition_id",""))
	var definition=Expedition.db.get_row("bags",id)
	var configured=str(definition.get("icon_ref",""))
	var release=configured.begins_with("res://Art/Supplied20261102/")
	if not key.is_empty():
		var supplied = preload("res://PvE/Art/SuppliedArt.gd").ui_path(key)
		var path = configured if release else supplied if not supplied.is_empty() else ROOT+key+".png"
		item.sprite.texture = AssetStream.resources.get(path) if AssetStream.resources.has(path) else load(path)
		item.sprite.centered = true; item.sprite.offset = Vector2.ZERO
		for child in item.sprite.find_children("*","Sprite2D",true,false): child.hide()
		var area = Vector2(184,150) if shop_view else Vector2.ONE*98 if storage_view else size*80.0*1.025
		if storage_view and Game.STORAGEBOX.has_meta("art_storage_slots"):area=Game.STORAGEBOX.pve_slot_rect(0).size-Vector2(6,6)
		var image_size = item.sprite.texture.get_size()
		var factor = area / image_size
		if shop_view or storage_view or release: factor = Vector2.ONE*minf(factor.x,factor.y)
		item.sprite.modulate=Color(Expedition.db.release_catalog.get("bag_tints",{}).get(id,"#ffffff"))
		item.spriteScale = factor; item.setSpriteScale(factor)
		item.sprite.position = anchor+size*40.0
		item.set_meta("polish_bag_art",key)
		item.set_meta("pve_sprite_position", item.sprite.position)
		item.set_meta("pve_visual_bounds",Rect2(item.sprite.position-image_size*factor*0.5,image_size*factor))
	elif not shop_view and not storage_view:
		# Keep the whole irregular original, enlarged to its own occupied envelope.
		var bounds: Rect2 = item.get_meta("pve_visual_bounds")
		var factor = minf(size.x*80.0/maxf(1,bounds.size.x),size.y*80.0/maxf(1,bounds.size.y))*0.99
		if factor > 1.01:
			item.spriteScale *= factor; item.setSpriteScale(item.spriteScale)
			var center = anchor+size*40.0
			item.sprite.position = center+(item.sprite.position-bounds.get_center())*factor
			item.set_meta("pve_sprite_position",item.sprite.position)
			item.set_meta("pve_visual_bounds",Rect2(center-bounds.size*factor*0.5,bounds.size*factor))
