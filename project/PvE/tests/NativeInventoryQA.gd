extends Node

var checks = 0
var failures: Array = []
var details: Dictionary = {}
var output = "user://native-inventory-report.json"

func _ready():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func frames(count: int = 4):
	for index in count: await get_tree().process_frame
	await preload("res://PvE/tests/LoadingBarrier.gd").wait_idle(get_tree())

func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)

func transaction_state(value: Dictionary) -> Dictionary:
	var copy = value.duplicate(true)
	copy.erase("play_seconds")
	return copy

func uid_view(uid: String):
	for item in Game.PLAYER.INVENTORY.items + Game.STORAGEBOX.items:
		if str(item.get_meta("pve_uid", "")) == uid: return item
	return null

func run_tests():
	var started = Time.get_ticks_msec()
	while not Expedition.initialized:
		if Time.get_ticks_msec() - started > 90000: check(false, "native initialize timeout"); finish(); return
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	Game.sceneAnimation.play("StartOnTitle"); Game.sceneAnimation.advance(100)
	Game.state = Game.State.Title
	check(Expedition.flow.new_run("armorer", "armorer_blades", "tutorial", 1337, true).ok, "fresh public new run")
	Expedition.flow.skip_tutorial()
	await frames()
	var route = -1
	for index in Expedition.flow.run.route_candidates.size():
		if str(Expedition.flow.run.route_candidates[index].type).ends_with("combat"): route = index; break
	if route < 0: route = 0
	check(Expedition.flow.choose_route(route).ok, "public route enters shop")
	await get_tree().create_timer(3.0).timeout
	await frames()
	check(Game.state == Game.State.Shop, "original native shop active")
	await shot("01-original-background-and-fitted-shop")
	# Exercise the native renderer's real tooltip and spatial hint helpers.
	for native in Game.PLAYER.INVENTORY.items:
		Game.PLAYER.INVENTORY.getAffectedCells(native, Item.Affected.Primary)
		if not native.isBag():
			native.mouseEntered()
			native.gainFocus()
			await frames(2)
			await shot("03-original-item-tooltip")
			native.mouseExited()
			break
	var selected = -1
	var at: Dictionary = {}
	for index in Expedition.flow.run.shop.slots.size():
		var slot: Dictionary = Expedition.flow.run.shop.slots[index]
		if int(slot.price) > int(Expedition.flow.run.gold) or Expedition.flow.placement.is_bag({"definition_id": slot.definition_id}): continue
		var candidate = Expedition.flow.run.build.duplicate(true)
		var entry = {"uid": "preview_offer", "definition_id": slot.definition_id, "x": 0, "y": 0, "rotation": 0}
		var placed = Expedition.flow.placement.auto_place(candidate, entry)
		if placed.ok:
			selected = index
			at = Expedition.flow.placement.find(candidate, "preview_offer").entry
			break
	check(selected >= 0, "native affordable offer has legal target")
	if selected >= 0:
		var offer = Game.shopSceneNode.slots[selected]
		var item = offer.item
		var before = Expedition.flow.run.duplicate(true)
		var uid = "%s_%d" % [str(before.run_id), int(before.next_uid)]
		item.pickup()
		Game.PLAYER.INVENTORY.orientItem(item, Vector2(at.x, at.y), int(at.rotation) / 90)
		check(Expedition.bridge.preview(item).ok, "original hover is green at legal offer target")
		var result = item.drop()
		item.reactToDropResult(result)
		await frames(8)
		check(result == Item.DropResult.AddedToInventory, "original Item pickup/drop/react buys")
		check(int(Expedition.flow.run.gold) == int(before.gold) - int(before.shop.slots[selected].price), "native purchase charges once")
		check(Expedition.flow.placement.find(Expedition.flow.run.build, uid).get("layer", "") in ["items", "bags"], "native purchase canonical generated UID")
		check(uid_view(uid) == item, "render retains original purchased scene identity")
		check(Game.getGold() == int(Expedition.flow.run.gold), "native encoded gold synchronized")
		var committed = Expedition.flow.run.duplicate(true)
		item.pickup()
		Game.PLAYER.INVENTORY.orientItem(item, Vector2(-2, -2), 0)
		var invalid = item.drop()
		item.reactToDropResult(invalid)
		await frames(8)
		check(invalid == Item.DropResult.OutsideInventory, "invalid native drop ends at saved position")
		check(transaction_state(Expedition.flow.run) == transaction_state(committed), "invalid drop leaves full run and RNG unchanged")
		check(uid_view(uid) == item and item.placed, "invalid drop restores same native instance")
		check(item.getTranslatedName() == Expedition.t(Expedition.flow.placement.definition(at.definition_id).name_key), "original tooltip shows configured name")
		check(Expedition.flow.edit("undo").ok, "public undo reverts native transaction")
		await frames(8)
		check(int(Expedition.flow.run.gold) == int(before.gold) and Expedition.flow.placement.find(Expedition.flow.run.build, uid).is_empty(), "undo restores gold and removes UID")
		check(Expedition.flow.edit("redo").ok, "public redo native transaction")
		await frames(8)
		check(not Expedition.flow.placement.find(Expedition.flow.run.build, uid).is_empty(), "redo restores canonical UID")
	# Move the newly purchased original item through the real recovered storage.
	var stored_uid = "%s_%d" % [str(Expedition.flow.run.run_id), int(Expedition.flow.run.next_uid) - 1]
	var stored_item = uid_view(stored_uid)
	check(is_instance_valid(stored_item), "storage candidate exists")
	if is_instance_valid(stored_item):
		stored_item.pickup()
		stored_item.global_position = Game.STORAGEBOX.getStorageRect().get_center()
		var storage_result = stored_item.drop()
		stored_item.reactToDropResult(storage_result)
		await frames(8)
		check(storage_result == Item.DropResult.AddedToStorageBox, "original storage drag commits")
		check(Expedition.flow.placement.find(Expedition.flow.run.build, stored_uid).get("layer", "") == "storage", "canonical storage entry retained")
		check(stored_item in Game.STORAGEBOX.items and stored_item.ownerType == Item.Owner.PlayerStorageBox, "original storage displays same scene")
		check(Expedition.flow.edit("undo").ok, "storage undo is one transaction")
		await frames(8)
		check(Expedition.flow.placement.find(Expedition.flow.run.build, stored_uid).get("layer", "") == "items", "storage undo restores backpack")
	# Buy another real offer directly into storage; its full metadata is retained.
	var storage_offer = -1
	for index in Expedition.flow.run.shop.slots.size():
		var slot: Dictionary = Expedition.flow.run.shop.slots[index]
		if not slot.sold and int(slot.price) <= int(Expedition.flow.run.gold): storage_offer = index; break
	if storage_offer >= 0:
		var before_storage = Expedition.flow.run.duplicate(true)
		var uid = "%s_%d" % [str(before_storage.run_id), int(before_storage.next_uid)]
		var item = Game.shopSceneNode.slots[storage_offer].item
		item.pickup()
		item.global_position = Game.STORAGEBOX.getStorageRect().get_center()
		var result = item.drop()
		item.reactToDropResult(result)
		await frames(8)
		var found = Expedition.flow.placement.find(Expedition.flow.run.build, uid)
		check(result == Item.DropResult.AddedToStorageBox and found.get("layer", "") == "storage", "native offer bought directly into storage")
		check(not found.is_empty() and int(found.entry.purchase_price) == int(before_storage.shop.slots[storage_offer].price) and int(found.entry.purchased_visit) == int(before_storage.visit), "direct storage preserves refund provenance")
		check(int(Expedition.flow.run.gold) == int(before_storage.gold) - int(before_storage.shop.slots[storage_offer].price), "direct storage charges once")
		check(Expedition.flow.edit("undo").ok, "direct storage purchase one undo")
		await frames(8)
		check(transaction_state(Expedition.flow.run) == transaction_state(before_storage), "direct storage undo restores full run")
	# Translation and clockwise rotation transform the whole recovered bag group.
	var bag: Dictionary = Expedition.flow.run.build.bags[0]
	var initial = Expedition.flow.run.duplicate(true)
	var move = Expedition.flow.move_bag_with_contents(str(bag.uid), {"x": int(bag.x) + 1, "y": int(bag.y), "rotation": int(bag.rotation)})
	check(move.ok, "filled bag group legal translation")
	await frames(8)
	var moved_bag = Expedition.flow.placement.find(Expedition.flow.run.build, str(bag.uid)).entry
	check(int(moved_bag.x) == int(bag.x) + 1 and Expedition.flow.placement.validate(Expedition.flow.run.build).ok, "group canonical geometry valid")
	check(Expedition.flow.edit("undo").ok, "group translation is one undo")
	await frames(8)
	check(transaction_state(Expedition.flow.run) == transaction_state(initial), "group undo restores entire run")
	var rotation = Expedition.flow.move_bag_with_contents(str(bag.uid), {"x": int(bag.x), "y": int(bag.y), "rotation": 90})
	check(rotation.ok, "filled bag legal rotation")
	await frames(8)
	check(Expedition.flow.placement.validate(Expedition.flow.run.build).ok, "rotation normalizes all child origins")
	var before_failure = Expedition.flow.run.duplicate(true)
	check(not Expedition.flow.move_bag_with_contents(str(bag.uid), {"x": 8, "y": 6, "rotation": 90}).ok, "group out of bounds rejected")
	check(transaction_state(Expedition.flow.run) == transaction_state(before_failure), "group failure preserves complete transaction")
	var large_textures: Array = []
	for node in all_nodes(Game.mainNode):
		if node is Sprite2D and node.texture != null and maxf(node.texture.get_size().x, node.texture.get_size().y) > 500:
			var ancestor = node
			while ancestor != null and not ancestor is Item: ancestor = ancestor.get_parent()
			large_textures.append({"node": str(node.get_path()), "texture": node.texture.resource_path, "size": str(node.texture.get_size()), "item": str(ancestor.descriptor.identifier) if ancestor != null else "", "pve": str(ancestor.get_meta("pve_definition_id", "")) if ancestor != null else "", "visible": node.is_visible_in_tree(), "sprite_scale": str(node.global_scale)})
	await shot("02-fitted-bag-rotation")
	details = {"large_textures": large_textures, "native_items": Game.PLAYER.INVENTORY.items.size(), "native_gold": Game.getGold(), "model_gold": Expedition.flow.run.gold}
	finish()

func shot(name: String):
	if DisplayServer.get_name() == "headless": return
	var path = ProjectSettings.globalize_path(output.get_base_dir().path_join("inventory-images"))
	DirAccess.make_dir_recursive_absolute(path)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.path_join(name + ".png"))

func all_nodes(parent: Node) -> Array:
	var nodes: Array = [parent]
	for child in parent.get_children(): nodes.append_array(all_nodes(child))
	return nodes

func finish():
	var report = {"checks": checks, "failures": failures, "details": details, "engine": Engine.get_version_info().string, "scope": "original Main.tscn + real Item.pickup/drop/reactToDropResult; no injected currency or health"}
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "  ")); file.close()
	print("NATIVE_INVENTORY_QA " + JSON.stringify(report))
	Game._begin_shutdown()
	await AssetStream.drain()
	await get_tree().create_timer(0.12, true, false, true).timeout
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)
