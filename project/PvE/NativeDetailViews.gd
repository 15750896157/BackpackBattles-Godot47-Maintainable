extends RefCounted

var owner
var category: String = "items"
var query: String = ""
var results: VBoxContainer
var rules

func _init(expedition):
	owner = expedition
	rules = load("res://PvE/Rules/content/RuleText.gd").new(owner.db)

func definition_text(id: String) -> String:
	var row = owner.flow.placement.definition(id)
	if row.is_empty(): return ""
	var text = owner.t(row.name_key) + " · " + owner.t("rarity." + str(row.get("rarity", "common"))) + "\n" + rules.item(id, TranslationServer.get_locale())
	if row.has("cooldown"):
		text += "\n" + owner.t("native.item_numbers", {"cooldown": row.cooldown, "stamina": row.stamina_cost, "price": row.base_price})
	var tags: Array[String] = []
	for tag in owner.db.list_values(row.get("tags", "")): tags.append(tag_name(str(tag)))
	if not tags.is_empty(): text += "\n" + owner.t("native.tags") + " · " + " / ".join(tags)
	return text

func tag_name(id: String) -> String:
	var row = owner.db.get_row("tags", id)
	return owner.t(str(row.get("name_key", "tag." + id + ".name")))

func enemy_snapshot(node: Dictionary) -> Dictionary:
	var difficulty = str(owner.flow.run.get("difficulty_id", "standard"))
	if not str(node.get("boss_id", "")).is_empty(): return owner.flow.snapshots.boss(node.boss_id, difficulty)
	return owner.flow.snapshots.enemy(str(node.get("enemy_id", "")), difficulty, node.get("affix_ids", node.get("affix_id", "")))

func show_enemy(node: Dictionary, phase: int = 1):
	owner.menus.journey.show_page(node,phase)

func grid(build: Dictionary, parent: Node) -> Control:
	var canvas = Control.new()
	canvas.custom_minimum_size = Vector2(558, 434)
	canvas.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	canvas.set_meta("pve_build_grid", true)
	parent.add_child(canvas)
	var supported: Dictionary = {}
	for bag in build.bags:
		for cell in owner.flow.placement.cells(bag): supported[cell] = true
	for y in 7:
		for x in 9:
			var tile = TextureRect.new()
			tile.texture = load("res://Art/Supplied20261028/ui/cell.png")
			tile.position = Vector2(x, y) * 62
			tile.size = Vector2(62, 62)
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.modulate = Color(1,1,1,0.38) if supported.has(Vector2i(x, y)) else Color(0.25, 0.25, 0.25, 0.12)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(tile)
	for entry in build.items:
		var cells = owner.flow.placement.local_cells(entry)
		var min_cell = Vector2i(999, 999)
		var max_cell = Vector2i(-999, -999)
		for cell in cells:
			min_cell = min_cell.min(cell)
			max_cell = max_cell.max(cell)
		var button = TextureButton.new()
		button.position = Vector2(Vector2i(int(entry.x), int(entry.y)) + min_cell) * 62
		button.size = Vector2(max_cell - min_cell + Vector2i.ONE) * 62
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var base = entry.duplicate(true)
		base.rotation = 0
		var base_cells = owner.flow.placement.local_cells(base)
		fill_grid_icon(weakref(button), entry.duplicate(true), base_cells, owner.popup_epoch)

		var hit_mask = BitMap.new()
		hit_mask.create(Vector2i(button.size))
		for cell in cells: hit_mask.set_bit_rect(Rect2i(Vector2i(cell - min_cell) * 62, Vector2i(62, 62)), true)
		button.texture_click_mask = hit_mask
		button.tooltip_text = definition_text(entry.definition_id) + "\n" + owner.t("native.placement", {"x": int(entry.x) + 1, "y": int(entry.y) + 1, "rotation": int(entry.rotation)})
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta("pve_entry", entry.duplicate(true))
		canvas.add_child(button)
	return canvas

func icon_row(id: String, text: String, parent: Node, hidden: bool = false):
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	parent.add_child(line)
	var icon = TextureRect.new()
	fill_icon(weakref(icon), id, owner.popup_epoch)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(78, 78)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hidden: icon.modulate = Color(0.12, 0.1, 0.08)
	line.add_child(icon)
	owner.label(text, line, 22)
	return line

func show_codex():
	owner.menus.library.show_page(category)

func populate():
	owner.menus.library.category=category;owner.menus.library.populate()

func fill_icon(target: WeakRef, id: String, epoch: int):
	var texture = await owner.bindings.texture_async(id)
	var icon = target.get_ref()
	if epoch != owner.popup_epoch or not is_instance_valid(icon) or icon.is_queued_for_deletion(): return
	icon.texture = texture

func fill_supplied_picture(target: WeakRef, key: String, epoch: int):
	var texture=await AssetStream.request_resource("res://Art/Supplied20261028/ui/"+key+".png","popup")
	var icon=target.get_ref()
	if epoch!=owner.popup_epoch or not is_instance_valid(icon) or icon.is_queued_for_deletion():return
	icon.texture=texture

func fill_grid_icon(target: WeakRef, entry: Dictionary, base_cells: Array, epoch: int):
	var texture = await owner.bindings.texture_async(str(entry.definition_id))
	if texture == null: return
	var button = target.get_ref()
	if epoch != owner.popup_epoch or not is_instance_valid(button) or button.is_queued_for_deletion(): return
	var layout = owner.bridge.footprint_layout.fit(owner.bridge.footprint_layout.picture(texture), base_cells)
	if layout.is_empty(): return
	var icon = Sprite2D.new()
	icon.texture = texture
	icon.scale = Vector2.ONE * float(layout.factor) * 62.0 / 80.0
	var angle = deg_to_rad(float(entry.rotation))
	var base_size = owner.bridge.footprint_layout.bounds(base_cells)
	var minimum = Vector2(INF, INF)
	for corner in [Vector2.ZERO, Vector2(base_size.x, 0), base_size, Vector2(0, base_size.y)]: minimum = minimum.min(corner.rotated(angle))
	icon.position = (Vector2(layout.origin).rotated(angle) / 80.0 - minimum) * 62.0
	icon.rotation = angle
	button.add_child(icon)
