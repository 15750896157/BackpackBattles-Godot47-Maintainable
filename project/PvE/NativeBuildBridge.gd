class_name NativeBuildBridge
extends RefCounted

# Original scene instances are views of the saved run. No original descriptor is
# changed: sprites, animations, picking shapes and sound remain recovered assets.
var expedition
var drop_pending: bool = false
var texture_bounds: Dictionary = {}
var rendered_builds: Dictionary = {}
var build_revisions: Dictionary = {}
var shop_revision: int = 0
var footprint_layout = preload("res://PvE/NativeFootprintLayout.gd").new()

func cancel_views():
	for owner in build_revisions.keys(): build_revisions[owner] += 1
	shop_revision += 1
	for scope in ["build-player", "build-enemy", "shop", "actor-enemy"]: AssetStream.release(scope)

func unload_run_views():
	for actor in [Game.PLAYER, Game.OPPONENT]:
		if is_instance_valid(actor) and actor.INVENTORY != null:
			for item in actor.INVENTORY.getItems().duplicate(): _retire(item)
			actor.INVENTORY.recalculateTilemap()
	if is_instance_valid(Game.STORAGEBOX):
		for item in Game.STORAGEBOX.getItems().duplicate(): _retire(item)
	for slot in Game.shopSceneNode.slots: slot.pve_reset()
	rendered_builds.clear()
	texture_bounds.clear()
	Game.itemLibrary.clear()
	ObjectPool.clear()
	AssetStream.release("fx-shared")
	AssetStream.release("fx-shop")
	AssetStream.release_metadata()

func _init(adapter):
	expedition = adapter

func is_view(item) -> bool:
	return expedition.enabled and item != null and item.has_meta("pve_definition_id")

func _flow():
	return expedition.flow

func slot_data(index: int) -> Dictionary:
	if _flow() == null or _flow().run.is_empty(): return {}
	var slots = _flow().run.get("shop", {}).get("slots", [])
	return slots[index] if index >= 0 and index < slots.size() else {}

func price_for_slot(slot) -> int:
	var index = int(slot) if slot is int else int(slot.index)
	return int(slot_data(index).get("price", 0))

func sell_price(item) -> int:
	if _flow() == null or _flow().run.is_empty(): return 0
	var found = _flow().placement.find(_flow().run.build, str(item.get_meta("pve_uid", "")))
	if found.is_empty(): return 0
	var entry: Dictionary = found.entry
	var base = int(_flow().placement.definition(str(entry.definition_id)).get("base_price", 0))
	var fresh = not bool(entry.get("used", false)) and int(entry.get("purchased_visit", -1)) == int(_flow().run.visit) and not bool(entry.get("crafted", false))
	if fresh: return int(entry.get("purchase_price", base))
	var ratio = clampf(float(expedition.db.value("used_sell_ratio", 0.5)) + float(_flow().run.get("sell_ratio_bonus", 0.0)), 0.0, 1.0)
	return maxi(1, int(floor(base * ratio)))

func sync_native_gold():
	if not _flow().run.is_empty(): Game.setGold(int(_flow().run.gold))

func _metadata(item, entry: Dictionary):
	item.set_meta("pve_uid", str(entry.get("uid", "")))
	item.set_meta("pve_definition_id", str(entry.definition_id))
	item.set_meta("pve_entry", entry.duplicate(true))
	item.set_meta("pve_shop_index", -1)
	item.set_meta("pve_preview", {})
	item.set_physics_process(false)

func _retire(item):
	if not is_instance_valid(item): return
	if item.dragged or Game.draggedItem == item: return
	if item.inventory != null and item in item.inventory.items: item.inventory.removeItem(item)
	if is_instance_valid(Game.STORAGEBOX) and item in Game.STORAGEBOX.items: Game.STORAGEBOX.removeItem(item)
	item.discard()

func render_build(character, build: Dictionary, owner: int):
	if character == null or character.INVENTORY == null or drop_pending: return
	if owner == Item.Owner.PlayerInventory and Game.draggedItem != null: return
	var inventory = character.INVENTORY
	var scope = "build-player" if owner == Item.Owner.PlayerInventory else "build-enemy"
	build_revisions[owner] = int(build_revisions.get(owner, 0)) + 1
	var revision = build_revisions[owner]
	if not await AssetStream.prepare_effects("shared"): return
	var ids: Array = []
	for layer in ["bags", "items", "storage"]:
		if layer == "storage" and owner != Item.Owner.PlayerInventory: continue
		for entry in build.get(layer, []): ids.append(entry.definition_id)
	if not await AssetStream.prepare(expedition.bindings.scene_paths(ids), scope): return
	if not is_instance_valid(character) or build_revisions.get(owner) != revision: return
	rendered_builds[inventory.get_instance_id()] = build.duplicate(true)
	var preview_items = _build_preview(owner)
	if owner == Item.Owner.PlayerInventory: Game.STORAGEBOX.pve_refresh_slots(build)
	var existing = {}
	for item in inventory.getItems().duplicate():
		if is_instance_valid(item): existing[str(item.get_meta("pve_uid", "native:" + str(item.get_instance_id())))] = item
	if owner == Item.Owner.PlayerInventory:
		for item in Game.STORAGEBOX.getItems().duplicate():
			if is_instance_valid(item): existing[str(item.get_meta("pve_uid", "native:" + str(item.get_instance_id())))] = item
	var wanted = {}
	for layer in ["bags", "items", "storage"]:
		if layer == "storage" and owner != Item.Owner.PlayerInventory: continue
		for entry in build.get(layer, []): wanted[str(entry.uid)] = entry
	for uid in existing:
		if not wanted.has(uid) or str(existing[uid].get_meta("pve_definition_id", "")) != str(wanted[uid].definition_id):
			_retire(existing[uid])
			existing[uid] = null
	# Bags before items builds the original tilemap without native auto-storage.
	for layer in ["bags", "items", "storage"]:
		if layer == "storage" and owner != Item.Owner.PlayerInventory: continue
		for entry in build.get(layer, []):
			var item = existing.get(str(entry.uid))
			if is_instance_valid(item) and item.dragged: continue
			if not is_instance_valid(item):
				item = await expedition.bindings.instance_async(str(entry.definition_id), Item.Owner.PlayerStorageBox if layer == "storage" else owner, scope)
				if build_revisions.get(owner) != revision or not is_instance_valid(character):
					if is_instance_valid(item): item.free()
					return
				if item == null: expedition.notice("native_asset_missing"); continue
				_metadata(item, entry)
				(inventory.itemNode if layer != "storage" else Game.STORAGEBOX).add_child(item)
			else:
				if item.inventory != null and item in item.inventory.items: item.inventory.removeItem(item)
				if item in Game.STORAGEBOX.items: Game.STORAGEBOX.removeItem(item)
				_metadata(item, entry)
			fit_native_visual(item, layer == "storage")
			if layer == "storage":
				Util.reparentNode(item, Game.STORAGEBOX)
				item.ownerType = Item.Owner.PlayerStorageBox
				item.inventory = null
				item.occupiedCells.clear()
				item.setFaceDirectionInstant(0)
				Game.STORAGEBOX.addItem(item)
				place_storage_view(item, build.storage.find(entry))
				item.makeGrabbable(true)
			else:
				Util.reparentNode(item, inventory.itemNode)
				item.ownerType = owner
				inventory.orientItem(item, Vector2(int(entry.x), int(entry.y)), int(entry.get("rotation", 0)) / 90)
				var cells: Array = []
				for cell in _flow().placement.cells(entry): cells.append(Vector2(cell))
				inventory.addItem(item, cells, false)
			item.set_physics_process(false)
			item.set_meta("pve_preview", preview_items.get(str(entry.uid), {}))
			if owner == Item.Owner.Opponent: item.disablePicking()
			else: Game.setItemEditMode(item)
			item.resetZ()
	inventory.recalculateTilemap()

func render_shop():
	if drop_pending or _flow().run.is_empty() or not is_instance_valid(Game.shopSceneNode): return
	if Game.draggedItem != null: return
	shop_revision += 1
	var revision = shop_revision
	if not await AssetStream.prepare_effects("shop"): return
	var ids: Array = []
	for offer in _flow().run.shop.get("slots", []):
		if not bool(offer.get("sold", false)): ids.append(offer.definition_id)
	if not await AssetStream.prepare(expedition.bindings.scene_paths(ids), "shop"): return
	if revision != shop_revision: return
	var shop = Game.shopSceneNode
	shop.chooseOneShop = false
	shop.chooseOneLabel.hide()
	shop.shopSignLabel.show()
	shop.rerollsThisRound = int(_flow().run.shop.get("refresh_count", 0))
	for index in shop.slots.size():
		var offer = shop.slots[index]
		var data = slot_data(index)
		if data.is_empty():
			offer.pve_reset()
			continue
		if bool(data.get("sold", false)):
			offer.pve_mark_sold()
			continue
		var same = is_instance_valid(offer.item) and not offer.bought and str(offer.item.get_meta("pve_definition_id", "")) == str(data.definition_id) and int(offer.item.get_meta("pve_shop_generation", -1)) == int(_flow().run.shop.get("generation", 0))
		if not same:
			offer.pve_reset()
			var item = await expedition.bindings.instance_async(str(data.definition_id), Item.Owner.Shop, "shop")
			if revision != shop_revision:
				if is_instance_valid(item): item.free()
				return
			if item == null: expedition.notice("native_asset_missing"); continue
			item.set_meta("pve_shop_index", index)
			item.set_meta("pve_shop_generation", int(_flow().run.shop.get("generation", 0)))
			item.set_meta("pve_uid", "")
			item.set_meta("pve_preview", {})
			item.set_meta("pve_purchase_committed", false)
			item.set_meta("pve_sell_committed", false)
			offer.setItem(item, Game.SaleMode.NoSale)
			item.set_meta("pve_drag_layout", false)
			fit_native_visual(item)
			item.setFaceDirectionInstant(0)
			item.position = offer.global_position - item.getBottomCenter() - Game.shopItemYSort.global_position
			item.popIn()
		offer.pve_sync(data)
	sync_native_gold()
	var rope = shop.get_node_or_null("Reroll/RerollRope")
	if rope != null and rope.has_method("updateTagTexture"): rope.updateTagTexture()
	CraftingManager.pve_refresh_candidates()

func refresh_shop() -> Dictionary:
	if expedition.syncing: return {"ok": false, "error": "native.drop_first"}
	var result = _flow().refresh_shop()
	if not result.ok: expedition.notice(str(result.error))
	else:
		Sound.playSound(Game.shopSceneNode.rerollSound, 6)
		Game.shopSceneNode.emit_signal("shop_refreshed")
	return result

func set_lock(slot, locked: bool) -> Dictionary:
	var index = int(slot) if slot is int else int(slot.index)
	if bool(slot_data(index).get("locked", false)) == locked: return {"ok": true}
	var result = _flow().toggle_lock(index)
	if not result.ok: expedition.notice(str(result.error))
	return result

func item_entry(item) -> Dictionary:
	var found = _flow().placement.find(_flow().run.get("build", {}), str(item.get_meta("pve_uid", "")))
	var entry: Dictionary = found.get("entry", {"definition_id": str(item.get_meta("pve_definition_id", ""))}).duplicate(true)
	if str(entry.get("uid", "")).is_empty():
		entry["uid"] = str(item.get_meta("pve_uid", ""))
		if str(entry.uid).is_empty(): entry.uid = "__native_offer_%d" % int(item.get_meta("pve_shop_index", -1))
	entry["rotation"] = posmod(int(item.getFaceDirection()) * 90, 360)
	return entry

func fit_native_visual(item, storage_view: bool = false):
	if not is_instance_valid(item.sprite) or item.sprite.texture == null: return
	var entry = item_entry(item)
	entry.rotation = 0
	var cells = _flow().placement.local_cells(entry)
	if cells.is_empty(): return
	var size = Vector2.ZERO
	for cell in cells:
		size.x = maxf(size.x, float(cell.x) + 1.0)
		size.y = maxf(size.y, float(cell.y) + 1.0)
	var anchor = Vector2(INF, INF)
	for cell in item.collisionCells:
		var point = item.collisionMap.position + LegacyGrid.cell_origin(item.collisionMap, cell)
		anchor.x = minf(anchor.x, point.x)
		anchor.y = minf(anchor.y, point.y)
	if not anchor.is_finite(): anchor = -size * 40.0
	item.set_meta("pve_anchor", anchor)
	item.set_meta("pve_size", size * 80.0)
	if not item.has_meta("pve_original_scale"):
		item.set_meta("pve_original_scale", item.spriteScale)
		item.set_meta("pve_original_offset", item.sprite.offset)
		item.set_meta("pve_original_texture", item.sprite.texture)
		item.set_meta("pve_original_centered", item.sprite.centered)
	var source_texture: Texture2D = item.get_meta("pve_original_texture", item.sprite.texture)
	# Preserve the entire original image, its mirrors, offset and child artwork.
	item.sprite.texture = source_texture
	item.sprite.centered = item.get_meta("pve_original_centered", true)
	item.sprite.offset = item.get_meta("pve_original_offset", Vector2.ZERO)
	var geometry = footprint_layout.geometry(item)
	var shop_view = item.ownerType == Item.Owner.Shop and not bool(item.get_meta("pve_drag_layout", false))
	var target_size = Game.STORAGEBOX.pve_slot_rect(0).size - Vector2(24, 34) if storage_view else Vector2(184, 160)
	if storage_view and Game.STORAGEBOX.has_meta("art_storage_rect"):
		# One independent storage item per supplied square, including long weapons.
		# The wider drop slot remains available, but its icon stays inside the cell.
		target_size = Vector2.ONE * minf(104.0, minf(target_size.x, target_size.y))
	var layout = footprint_layout.rectangle(geometry, target_size) if storage_view or shop_view else footprint_layout.fit(geometry, cells)
	var original_scale: Vector2 = item.get_meta("pve_original_scale")
	item.spriteScale = original_scale * float(layout.factor)
	item.setSpriteScale(item.spriteScale)
	var position = anchor + Vector2(layout.origin)
	if storage_view or shop_view: position += size * 40.0 - target_size * 0.5
	item.set_meta("pve_sprite_position", position)
	item.set_meta("pve_visual_fit", {"turn": 0, "bag_mask": false, "original_texture": true, "mode": layout.mode, "factor": layout.factor})
	var visual_bounds = Rect2(position + Vector2(geometry.minimum) * float(layout.factor), Vector2(geometry.size) * float(layout.factor))
	item.set_meta("pve_visual_bounds", visual_bounds)
	item.sprite.position = position
	preload("res://PvE/Art/BagArt.gd").apply(item,cells,anchor,size,shop_view,storage_view)
	visual_bounds = item.get_meta("pve_visual_bounds")
	item.updateShadowTexture()
	item.updateShadow()
	# The old scene's tilemap describes its old footprint and inherits icon scale.
	# Actual occupied/support cells are drawn by the authoritative inventory map.
	item.collisionMap.hide()
	if item.isBag(): item.bagTilemap.hide()
	var pick_signature = str(entry.definition_id) + (":storage" if storage_view else ":shop" if shop_view else ":grid")
	if str(item.get_meta("pve_pick_definition", "")) == pick_signature: return
	item.set_meta("pve_pick_definition", pick_signature)
	# Pixel picking uses the same recovered 80px cells as the authoritative build.
	# Disable old oversized shapes without editing their saved scene resources.
	for child in item.clickArea.get_children():
		if child.has_meta("pve_pick_cell"): child.queue_free()
		elif child is CollisionShape2D or child is CollisionPolygon2D:
			if not child.has_meta("pve_original_disabled"): child.set_meta("pve_original_disabled", child.disabled)
			child.set_deferred("disabled", true)
	var pick_cells = [Vector2i.ZERO] if storage_view or shop_view else cells
	for cell in pick_cells:
		var shape = CollisionShape2D.new()
		shape.set_meta("pve_pick_cell", true)
		var rectangle = RectangleShape2D.new()
		rectangle.size = visual_bounds.size + Vector2(10, 10) if shop_view else target_size if storage_view else Vector2(78, 78)
		shape.shape = rectangle
		item.clickArea.add_child(shape)
		var center = visual_bounds.get_center() if shop_view else anchor + size * 40.0 if storage_view else anchor + (Vector2(cell) + Vector2(0.5, 0.5)) * 80.0
		shape.position = item.clickArea.to_local(item.to_global(center))
	for child in item.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			if child.has_meta("pve_body_cell"): child.queue_free()
			else:
				if not child.has_meta("pve_original_disabled"): child.set_meta("pve_original_disabled", child.disabled)
				child.set_deferred("disabled", true)
	for cell in pick_cells:
		var shape = CollisionShape2D.new()
		shape.set_meta("pve_body_cell", true)
		var rectangle = RectangleShape2D.new()
		rectangle.size = visual_bounds.size + Vector2(10, 10) if shop_view else target_size if storage_view else Vector2(78, 78)
		shape.shape = rectangle
		shape.position = visual_bounds.get_center() if shop_view else anchor + size * 40.0 if storage_view else anchor + (Vector2(cell) + Vector2(0.5, 0.5)) * 80.0
		item.add_child(shape)

func reset_native_visual(item):
	if item.has_meta("pve_original_scale"):
		item.spriteScale = item.get_meta("pve_original_scale")
		item.setSpriteScale(item.spriteScale)
		item.sprite.offset = item.get_meta("pve_original_offset")
		item.sprite.texture = item.get_meta("pve_original_texture", item.sprite.texture)
		item.sprite.centered = item.get_meta("pve_original_centered", true)
		item.sprite.position = Vector2.ZERO
		item.updateShadowTexture()
	for parent in [item, item.clickArea]:
		for child in parent.get_children():
			if child.has_meta("pve_pick_cell") or child.has_meta("pve_body_cell"):
				child.set_deferred("disabled", true)
				child.queue_free()
			elif child.has_meta("pve_original_disabled"):
				child.set_deferred("disabled", bool(child.get_meta("pve_original_disabled")))
				child.remove_meta("pve_original_disabled")
	for key in item.get_meta_list():
		if str(key).begins_with("pve_"): item.remove_meta(key)

func grid_points(item) -> Array:
	var points: Array = []
	var entry = item_entry(item)
	var origin: Vector2 = item.getTopLeftGlobal()
	for cell in _flow().placement.local_cells(entry): points.append(origin + (Vector2(cell) + Vector2(0.5, 0.5)) * 80.0)
	return points

func _build_preview(owner: int) -> Dictionary:
	if _flow().run.is_empty(): return {}
	var player = _flow().snapshots.player(_flow().run)
	if not bool(player.get("ok", false)): return {}
	var enemy = {} if _flow().run.current_node.is_empty() or _flow().run.current_node.get("type", "") == "merchant" else _flow().snapshot_enemy(_flow().run.current_node)
	if not enemy.is_empty() and not bool(enemy.get("ok", false)): enemy = {}
	if owner == Item.Owner.Opponent:
		if enemy.is_empty(): return {}
		var result = load("res://PvE/Rules/combat/CombatEngine.gd").new(expedition.db).preview(enemy, player)
		return result.get("items", {}) if bool(result.get("ok", false)) else {}
	var result = load("res://PvE/Rules/combat/CombatEngine.gd").new(expedition.db).preview(player, enemy)
	return result.get("items", {}) if bool(result.get("ok", false)) else {}

func definition_stats(id: String) -> Dictionary:
	var definition = _flow().placement.definition(id)
	var damage = 0.0
	for effect in expedition.db.rows("item_effects"):
		if str(effect.item_id) == id and str(effect.effect_type) in ["physical_damage", "true_damage"]:
			var params = expedition.db.parse_params(effect.effect_params)
			damage += maxf(0.0, float(params.get("value", params.get("amount", 0.0))))
	var crit = float(expedition.db.get_row("characters", str(_flow().run.get("character_id", "armorer"))).get("base_crit_chance", 0.05))
	return {"base_damage": damage, "damage": damage, "base_cooldown": float(definition.get("cooldown", 0.0)), "cooldown": float(definition.get("cooldown", 0.0)), "crit_chance": crit, "stamina_cost": float(definition.get("stamina_cost", 0.0))}

func target_origin(item) -> Vector2i:
	var inventory = Game.PLAYER.INVENTORY
	var center = inventory.tilemap.to_local(item.getTopLeftGlobal() + Vector2(40, 40))
	return Vector2i(LegacyGrid.cell(inventory.tilemap, center))

func bag_contents(item) -> Array:
	var result: Array = []
	if not item.isBag() or item.inventory == null: return result
	var found = _flow().placement.find(_flow().run.build, str(item.get_meta("pve_uid", "")))
	if found.is_empty() or found.layer != "bags": return result
	var bag_cells = _flow().placement.cells(found.entry)
	for entry in _flow().run.build.items:
		var completely_inside = true
		for cell in _flow().placement.cells(entry):
			if cell not in bag_cells: completely_inside = false; break
		if not completely_inside: continue
		for view in item.inventory.items:
			if str(view.get_meta("pve_uid", "")) == str(entry.uid):
				result.append(view); break
	return result

func preview(item) -> Dictionary:
	if _flow().run.is_empty(): return {"ok": false, "error": "wrong_state"}
	var entry = item_entry(item)
	var origin = target_origin(item)
	if item.ownerType == Item.Owner.PlayerInventory and _flow().placement.is_bag(entry):
		return _flow().move_bag_with_contents(str(entry.get("uid", "")), {"x": origin.x, "y": origin.y, "rotation": int(entry.rotation), "preview": true})
	return _flow().placement.preview(_flow().run.build, entry, origin.x, origin.y, int(entry.rotation))

func affected_cells(item, color: int, inventory) -> Dictionary:
	var result = {inventory.AffectedTile.CanAffect + color: [], inventory.AffectedTile.CannotAffect + color: [], inventory.AffectedTile.AffectsInside: []}
	if color != Item.Affected.Primary: return result
	var build: Dictionary = rendered_builds.get(inventory.get_instance_id(), _flow().run.get("build", {})).duplicate(true)
	var entry = item_entry(item)
	if item.dragged or item.ownerType == Item.Owner.Shop:
		var origin = target_origin(item)
		var status = _flow().placement.preview(build, entry, origin.x, origin.y, int(entry.rotation))
		if not status.ok: return result
		build = status.build
		entry = status.entry
	var targets: Dictionary = {}
	if _flow().placement.is_bag(entry):
		for candidate in build.items:
			for special in _flow().spatial.active_special_effects(build, str(candidate.uid)):
				if str(special.bag_uid) == str(entry.uid):
					targets[str(candidate.uid)] = true; break
	else:
		for effect in expedition.db.rows("item_effects"):
			if str(effect.item_id) != str(entry.definition_id) or str(effect.spatial_template_id) == "none": continue
			for uid in _flow().spatial.relations(build, str(entry.uid), str(effect.spatial_template_id)):
				var can_affect = true
				var condition = str(effect.condition_id)
				if condition in ["source_has_tag", "target_has_tag", "spatial_target_count", "build_tag_count", "no_spatial_tag", "distinct_adjacent_tags"]:
					var params = expedition.db.parse_params(effect.condition_params)
					if not params.has("template"): params["template"] = str(effect.spatial_template_id)
					can_affect = _flow().spatial.condition(build, str(entry.uid), condition, params, str(uid))
				targets[uid] = bool(targets.get(uid, false)) or can_affect
	for uid in targets:
		var found = _flow().placement.find(build, str(uid))
		if found.is_empty(): continue
		for cell in _flow().placement.cells(found.entry):
			var point = Vector2(cell)
			var tile = inventory.AffectedTile.CanAffect + color if bool(targets[uid]) else inventory.AffectedTile.CannotAffect + color
			if point not in result[tile]: result[tile].append(point)
	return result

func _buy_to_storage(index: int) -> Dictionary:
	var before = _flow().run.duplicate(true)
	var draft = before.duplicate(true)
	var bought = _flow().economy.buy(draft, index)
	if not bought.ok: return bought
	if not bought.stored:
		var stored = _flow().placement.remove(draft.build, str(bought.entry.uid), true)
		if not stored.ok: return stored
	_flow().run.clear()
	_flow().run.merge(draft, true)
	_flow().edit_history.record(before, _flow().run)
	_flow().profile_service.discover(str(bought.entry.definition_id))
	_flow().mark_tutorial("buy_item")
	_flow().mark_tutorial("store_item")
	_flow().telemetry.record("item_purchased", {"item_id": bought.entry.definition_id, "price": bought.price, "act": draft.act, "slot": index})
	return _flow()._update()

func _restore_native(item):
	item.resetSprite()
	var children = item.draggedInsideItems.duplicate()
	item.reparentItemsInside()
	for child in children: _restore_native(child)
	var uid = str(item.get_meta("pve_uid", ""))
	var found = _flow().placement.find(_flow().run.build, uid)
	if not found.is_empty():
		_metadata(item, found.entry)
		if found.layer == "storage":
			Util.reparentNode(item, Game.STORAGEBOX)
			item.ownerType = Item.Owner.PlayerStorageBox
			item.inventory = null
			if item not in Game.STORAGEBOX.items: Game.STORAGEBOX.addItem(item)
			fit_native_visual(item, true)
			item.setFaceDirectionInstant(0)
			place_storage_view(item, int(found.index))
			item.makeGrabbable(true)
		else:
			var inventory = Game.PLAYER.INVENTORY
			Util.reparentNode(item, inventory.itemNode)
			item.ownerType = Item.Owner.PlayerInventory
			fit_native_visual(item)
			inventory.orientItem(item, Vector2(found.entry.x, found.entry.y), int(found.entry.rotation) / 90)
			if item in inventory.items: inventory.removeItem(item)
			if item not in inventory.items:
				var cells: Array = []
				for cell in _flow().placement.cells(found.entry): cells.append(Vector2(cell))
				inventory.addItem(item, cells, false)
	else:
		item.ownerType = Item.Owner.Shop
		item.set_meta("pve_drag_layout", false)
		fit_native_visual(item)
		Util.reparentNode(item, Game.shopItemYSort)
		item.global_position = item.pickupPosition
		item.setFaceDirectionInstant(0)

func drop_item(item) -> int:
	Util.finishTween(item.rotationTween)
	if _flow().screen_state != "SHOP_PREPARE":
		_restore_native(item)
		return Item.DropResult.OutsideInventory
	var was_shop = item.ownerType == Item.Owner.Shop
	var index = int(item.get_meta("pve_shop_index", -1))
	var uid = str(item.get_meta("pve_uid", ""))
	var next_uid = "%s_%d" % [str(_flow().run.run_id), int(_flow().run.next_uid)]
	var origin = target_origin(item)
	var rotation = int(item.getFaceDirection()) * 90
	var sale_amount = sell_price(item) if not was_shop else 0
	var result: Dictionary
	var drop_result = Item.DropResult.AddedToInventory
	expedition.syncing = true
	drop_pending = true
	if Game.SELLBOX.isHovered():
		result = {"ok": false, "error": "missing_item"} if was_shop else _flow().sell(uid)
		drop_result = Item.DropResult.Sold
	elif Game.STORAGEBOX.isHovered():
		result = _buy_to_storage(index) if was_shop else _flow().edit("store", uid)
		drop_result = Item.DropResult.AddedToStorageBox
	else:
		if not was_shop and item.isBag() and item.ownerType == Item.Owner.PlayerInventory:
			result = _flow().move_bag_with_contents(uid, {"x": origin.x, "y": origin.y, "rotation": rotation})
		else:
			result = _flow().buy_at(index, origin.x, origin.y, rotation) if was_shop else _flow().edit("move", uid, {"x": origin.x, "y": origin.y, "rotation": rotation})
		if not result.ok and not was_shop and str(result.get("error", "")) == "overlap":
			var other = _collision_uid(item, origin, rotation)
			if not other.is_empty(): result = _flow().edit("swap", uid, {"other_uid": other})
	if result.ok or bool(result.get("committed_in_memory", false)):
		if not result.ok: expedition.notice(str(result.get("error", "save_write_failed")))
		if was_shop:
			item.set_meta("pve_uid", next_uid)
			# The original offer's dropped signal plays its Bought animation later.
			item.set_meta("pve_purchase_committed", true)
		if drop_result == Item.DropResult.Sold:
			item.sold = true
			item.set_meta("pve_sell_committed", true)
			item.set_meta("pve_sell_price", sale_amount)
			Game.SELLBOX.sellItem(item)
		else: _restore_native(item)
		sync_native_gold()
	else:
		expedition.notice(str(result.get("error", "wrong_state")))
		_restore_native(item)
		# A rejected drop ends dragging at its saved origin. It must not count as
		# a successful purchase in the native ShopOffer dropped signal.
		drop_result = Item.DropResult.OutsideInventory
	item.dragged = false
	if drop_result != Item.DropResult.Sold: item.resetSprite()
	expedition.call_deferred("set", "syncing", false)
	call_deferred("_finish_drop")
	return drop_result

func _finish_drop():
	drop_pending = false
	expedition.request_render()

func cancel_drag(item):
	expedition.syncing = true
	drop_pending = true
	_restore_native(item)
	item.reactToDropResult(Item.DropResult.OutsideInventory)
	expedition.call_deferred("set", "syncing", false)
	call_deferred("_finish_drop")

func store_item(item) -> Dictionary:
	var was_shop = item.ownerType == Item.Owner.Shop
	var next_uid = "%s_%d" % [str(_flow().run.get("run_id", "run")), int(_flow().run.get("next_uid", 1))]
	expedition.syncing = true
	drop_pending = true
	var result = _buy_to_storage(int(item.get_meta("pve_shop_index", -1))) if was_shop else _flow().edit("store", str(item.get_meta("pve_uid", "")))
	if result.ok or bool(result.get("committed_in_memory", false)):
		if was_shop:
			item.set_meta("pve_uid", next_uid)
			item.set_meta("pve_purchase_committed", true)
		if item.inventory != null and item in item.inventory.items: item.inventory.removeItem(item)
		_restore_native(item)
		sync_native_gold()
	else:
		expedition.notice(str(result.get("error", "wrong_state")))
		if item.dragged: _restore_native(item)
	expedition.call_deferred("set", "syncing", false)
	call_deferred("_finish_drop")
	return result

func _collision_uid(item, origin: Vector2i, rotation: int) -> String:
	var entry = item_entry(item)
	entry.x = origin.x; entry.y = origin.y; entry.rotation = rotation
	var layer = "bags" if _flow().placement.is_bag(entry) else "items"
	var collisions = []
	for other in _flow().run.build[layer]:
		if str(other.uid) == str(entry.get("uid", "")): continue
		for cell in _flow().placement.cells(other):
			if cell in _flow().placement.cells(entry):
				collisions.append(str(other.uid)); break
	return collisions[0] if collisions.size() == 1 else ""

func shift_inventory(direction: Vector2) -> Dictionary:
	if _flow().screen_state != "SHOP_PREPARE": return {"ok": false, "error": "wrong_state"}
	var before = _flow().run.duplicate(true)
	var draft = before.duplicate(true)
	var layers = ["bags", "items"]
	if Game.inventoryEditMode == Game.InventoryEditMode.BagLayer: layers = ["bags"]
	elif Game.inventoryEditMode == Game.InventoryEditMode.ItemLayer: layers = ["items"]
	for layer in layers:
		for entry in draft.build[layer]: entry.x += int(direction.x); entry.y += int(direction.y)
	var checked = _flow().placement.validate(draft.build)
	if not checked.ok: expedition.notice(str(checked.error)); return checked
	_flow().run.clear(); _flow().run.merge(draft, true)
	_flow().edit_history.record(before, _flow().run)
	return _flow()._update()

func place_storage_view(item, index: int):
	item.makeNonRigidBody()
	var center = Vector2(item.get_meta("pve_anchor")) + Vector2(item.get_meta("pve_size")) * 0.5
	item.global_position += Game.STORAGEBOX.pve_slot_rect(index).get_center() - item.to_global(center)
