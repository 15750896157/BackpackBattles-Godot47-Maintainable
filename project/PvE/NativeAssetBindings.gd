class_name NativeAssetBindings
extends RefCounted

const BINDINGS_PATH = "res://PvE/asset_bindings.json"
var db
var bindings: Dictionary = {}
var errors: Array = []
var texture_cache: Dictionary = {}

func _init(content = null):
	db = content
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS_PATH))
	if not parsed is Dictionary or not parsed.get("bindings") is Dictionary:
		errors.append("native_asset_bindings_unavailable")
		return
	bindings = parsed.bindings

func descriptor_for(definition_id: String):
	var binding: Dictionary = bindings.get(definition_id, {})
	if binding.is_empty():
		errors.append("unmapped_definition:" + definition_id)
		return null
	var tree = Engine.get_main_loop() as SceneTree
	var book = tree.root.get_node_or_null("ItemBook") if tree != null else null
	if book == null:
		errors.append("item_book_not_initialized:" + definition_id)
		return null
	var descriptors = book.get("items")
	var original_name = str(binding.get("name", ""))
	if not descriptors is Dictionary or not descriptors.has(original_name):
		errors.append("original_descriptor_missing:" + original_name)
		return null
	return descriptors[original_name]

func instance(definition_id: String, owner_type: int):
	var descriptor = descriptor_for(definition_id)
	if descriptor == null: return null
	var tree = Engine.get_main_loop() as SceneTree
	var book = tree.root.get_node("ItemBook")
	var original = book.instantiateItem(descriptor)
	if original == null:
		errors.append("original_item_instantiation_failed:" + definition_id)
		return null
	# The bridge adds this item to an inventory later. Native _ready must see the
	# correct owner; this service never adds it to a tree or runs a battle effect.
	original.ownerType = owner_type
	original.set_meta("pve_definition_id", definition_id)
	original.set_meta("pve_original_name", str(bindings[definition_id].name))
	original.set_meta("pve_original_scene", str(bindings[definition_id].scene))
	return original

func scene_paths(ids: Array) -> Array:
	var paths: Array = []
	for id in ids:
		var binding: Dictionary = bindings.get(str(id), {})
		var path = str(binding.get("scene", ""))
		if not path.is_empty() and path not in paths: paths.append(path)
		var bag_path = replacement_path(str(id))
		if not bag_path.is_empty() and bag_path not in paths: paths.append(bag_path)
	return paths

func instance_async(definition_id: String, owner_type: int, scope: String):
	var descriptor = descriptor_for(definition_id)
	if descriptor == null: return null
	var original = await AssetStream.instantiate_path(descriptor.scene_path, scope)
	if original == null: return null
	original.descriptor = descriptor
	original.ownerType = owner_type
	original.set_meta("pve_definition_id", definition_id)
	original.set_meta("pve_original_name", str(bindings[definition_id].name))
	original.set_meta("pve_original_scene", str(bindings[definition_id].scene))
	ItemBook.call_deferred("emit_signal", "item_instantiated_deferred", original)
	return original

func texture_for(definition_id: String) -> Texture2D:
	if texture_cache.has(definition_id): return texture_cache[definition_id]
	var binding: Dictionary = bindings.get(definition_id, {})
	if binding.is_empty(): return null
	var texture_path = replacement_path(definition_id)
	if texture_path.is_empty(): texture_path = str(binding.get("png", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var image = ResourceLoader.load(texture_path)
		if image is Texture2D:
			texture_cache[definition_id] = image
			return image
	var original_scene = ResourceLoader.load(str(binding.get("scene", "")))
	if original_scene is PackedScene:
		var image = _scene_texture(original_scene.get_state())
		if image != null:
			texture_cache[definition_id] = image
			return image
	errors.append("original_texture_missing:" + definition_id)
	return null

func texture_path(definition_id: String) -> String:
	var replacement = replacement_path(definition_id)
	if not replacement.is_empty(): return replacement
	var binding: Dictionary = bindings.get(definition_id, {})
	var png = str(binding.get("png", ""))
	return png if not png.is_empty() else str(binding.get("scene", ""))

func replacement_path(definition_id: String) -> String:
	var supplied = preload("res://PvE/Art/SuppliedArt.gd").item_path(definition_id)
	if not supplied.is_empty(): return supplied
	var definition = db.get_row("bags",definition_id) if db != null else {}
	if definition.is_empty(): return ""
	var cells: Array = []
	# Authoritative dimensions, not the recovered native scene's different bag size.
	if Expedition.flow != null:
		cells = Expedition.flow.placement.local_cells({"definition_id":definition_id,"rotation":0})
	var key = preload("res://PvE/Art/BagArt.gd").key_for(cells)
	if key == "bag9": return preload("res://PvE/Art/SuppliedArt.gd").ui_path(key)
	return "res://Art/Polish20261022/"+key+".png" if not key.is_empty() else ""

func texture_async(definition_id: String) -> Texture2D:
	var resource = await AssetStream.request_resource(texture_path(definition_id), "popup")
	if resource is Texture2D: return resource
	if resource is PackedScene: return _scene_texture(resource.get_state())
	return null

func _scene_texture(state: SceneState) -> Texture2D:
	for pass_index in 2:
		for index in state.get_node_count():
			var path = str(state.get_node_path(index))
			var is_icon = str(state.get_node_name(index)) == "Icon"
			if pass_index == 0 and not is_icon: continue
			if pass_index == 1 and not (path.begins_with("Icon/") or path.contains("/Icon/")): continue
			for property_index in state.get_node_property_count(index):
				if str(state.get_node_property_name(index, property_index)) == "texture":
					var image = state.get_node_property_value(index, property_index)
					if image is Texture2D: return image
	var base = state.get_base_scene_state()
	if base != null: return _scene_texture(base)
	return null
