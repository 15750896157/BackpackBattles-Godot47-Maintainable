class_name ItemTemplate
extends RefCounted
## 物品模板试点：新基场景 PvE/Items/ItemBase.tscn + 数据覆盖（PvE/item_template_overrides.json）。
## 覆盖数据由 tz/extract_item_overrides.py 从原版场景逐字段提取，等价原版"基场景+文件覆盖"模式。
## 全部覆盖在物品进树前应用：换脚本/建碰撞节点/铺格子都在 _ready 之前就位。

const TEMPLATE_PATH := "res://PvE/Items/ItemBase.tscn"
const OVERRIDES_PATH := "res://PvE/item_template_overrides.json"
const GEM_SOCKET_SCENE := "res://Items/GemSocket.tscn"

static var _by_definition: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))
	if not parsed is Dictionary or not parsed.get("items") is Dictionary:
		push_error("ItemTemplate: overrides JSON unavailable: " + OVERRIDES_PATH)
		return
	for key in parsed.items:
		var data: Dictionary = parsed.items[key]
		for id in data.get("definition_ids", []):
			_by_definition[str(id)] = data

static func override_for(definition_id: String) -> Dictionary:
	_load()
	return _by_definition.get(definition_id, {})

## 该绑定用哪个基场景：宝石走 GemBase（ItemBase 的子场景，照抄原版 Item→Gem 层级），其余 ItemBase。
static func template_scene_for(data: Dictionary) -> String:
	return str(data.get("template_scene", TEMPLATE_PATH))

## 预加载清单：模板场景 + 贴图（+ shader + 额外节点引用的资源）。返回空数组 = 该绑定不走模板。
static func preload_paths(definition_id: String) -> Array:
	var data = override_for(definition_id)
	if data.is_empty(): return []
	var paths: Array = [template_scene_for(data), str(data.icon.texture)]
	var mat = data.icon.get("material")
	if mat is Dictionary and not paths.has(str(mat.shader)): paths.append(str(mat.shader))
	# 宝石孔：整场景实例 GemSocket.tscn
	if not data.get("gem_sockets", []).is_empty() and not paths.has(GEM_SOCKET_SCENE):
		paths.append(GEM_SOCKET_SCENE)
	# 格区 TileMap：外部 TileSet .tres
	if data.has("icon_tilemap") and not paths.has(str(data.icon_tilemap.tile_set)):
		paths.append(str(data.icon_tilemap.tile_set))
	# 条件槽位（粒子等）额外节点引用的资源（.tres/.material/.png；整场景实例的 .tscn）
	for spec in data.get("extra_nodes", []):
		if str(spec.get("scene", "")) != "" and not paths.has(str(spec.scene)):
			paths.append(str(spec.scene))
		for key in spec.get("props", {}):
			var value = spec.props[key]
			if value is Dictionary and value.has("res") and not paths.has(str(value.res)):
				paths.append(str(value.res))
	return paths

static func apply(item: Node, data: Dictionary, scope: String) -> bool:
	item.name = str(data.root_name)
	var pm = PhysicsMaterial.new()
	pm.friction = float(data.physics.friction)
	pm.bounce = float(data.physics.bounce)
	item.physics_material_override = pm
	# 进树前换脚本：物品专属脚本都极简（无 _init/export），_ready 尚未运行，安全。
	item.set_script(load(str(data.script)))
	# 根节点属性覆盖（药剂类：potionColor @export Color、Laboratory 的 rotation）。
	for key in data.get("root_props", {}):
		var value = data.root_props[key]
		item.set(key, Color(value[0], value[1], value[2], value[3]) if value is Array else float(value))
	var icon: Sprite2D = item.get_node("Icon")
	icon.position = Vector2(data.icon.position[0], data.icon.position[1])
	icon.scale = Vector2(data.icon.scale[0], data.icon.scale[1])
	if data.icon.has("rotation"):
		icon.rotation = float(data.icon.rotation)
	if data.icon.has("offset"):
		icon.offset = Vector2(data.icon.offset[0], data.icon.offset[1])
	icon.texture = await AssetStream.request_resource(str(data.icon.texture), scope)
	if icon.texture == null:
		push_error("ItemTemplate: icon texture missing " + str(data.icon.texture))
		return false
	var mat = data.icon.get("material")
	if mat is Dictionary:
		var material = ShaderMaterial.new()
		material.shader = await AssetStream.request_resource(str(mat.shader), scope)
		for key in mat.params:
			var value = mat.params[key]
			material.set_shader_parameter(key, Vector2(value[0], value[1]) if value is Array else value)
		icon.material = material
	# Icon 挂脚本（SpringLoader 的 SpringloaderVisual.gd 弹簧回弹）：进树前 set_script + @export 覆盖，
	# @onready（$Spring/$Sockets/get_parent）在 _ready 才解析，节点此刻已由数据建全。
	if data.icon.has("script"):
		icon.set_script(load(str(data.icon.script)))
		for key in data.icon.script_props:
			icon.set(key, data.icon.script_props[key])
	item.get_node("Icon/Sockets").scale = Vector2(data.sockets_scale[0], data.sockets_scale[1])
	# 宝石孔：按数据实例化 GemSocket.tscn，位置是 Sockets 本地坐标。必须在进树前挂好，
	# Item.gd 的 @onready sockets = $Icon/Sockets.get_children() 才收得到。
	var socket_specs: Array = data.get("gem_sockets", [])
	if not socket_specs.is_empty():
		var gem_scene = await AssetStream.request_resource(GEM_SOCKET_SCENE, scope)
		for spec in socket_specs:
			var socket = gem_scene.instantiate()
			socket.name = str(spec.name)
			socket.position = Vector2(spec.position[0], spec.position[1])
			item.get_node("Icon/Sockets").add_child(socket)
	var map: TileMap = item.get_node("CollisionMap")
	map.position = Vector2(data.collision_map.position[0], data.collision_map.position[1])
	map.clear()
	for cell in data.collision_map.cells:
		map.set_cell(0, Vector2i(cell[0], cell[1]), int(cell[2]), Vector2i.ZERO, 0)
	# 格区 TileMap（Bag.gd @onready $Icon/TileMap 硬接口：潜在格半透明显示）。进树前建好铺好。
	if data.has("icon_tilemap"):
		var spec_tm: Dictionary = data.icon_tilemap
		var bag_map: TileMap = TileMap.new()
		bag_map.name = "TileMap"
		bag_map.tile_set = await AssetStream.request_resource(str(spec_tm.tile_set), scope)
		bag_map.modulate = Color(spec_tm.modulate[0], spec_tm.modulate[1], spec_tm.modulate[2], spec_tm.modulate[3])
		bag_map.position = Vector2(spec_tm.position[0], spec_tm.position[1])
		bag_map.scale = Vector2(spec_tm.scale[0], spec_tm.scale[1])
		for cell in spec_tm.cells:
			bag_map.set_cell(0, Vector2i(cell[0], cell[1]), int(cell[2]), Vector2i.ZERO, 0)
		item.get_node("Icon").add_child(bag_map)
	item.get_node("ClickArea/CollisionPolygon2D").polygon = _poly(data.click_polygon)
	if data.has("click_position"):
		item.get_node("ClickArea/CollisionPolygon2D").position = Vector2(data.click_position[0], data.click_position[1])
	# ClickArea 节点自身的覆盖（第六刀漏收、本刀补上：Chainsaw position=(0,-99) 错位 bug 在此修复）。
	if data.has("click_area_position"):
		item.get_node("ClickArea").position = Vector2(data.click_area_position[0], data.click_area_position[1])
	if data.get("click_area_visible", false):
		item.get_node("ClickArea").visible = true
	item.get_node("BottomCenter").position = Vector2(data.bottom_center[0], data.bottom_center[1])
	# Lock 覆盖（锁图标 Sprite2D：第五刀漏收、本刀补上——Pot/SpikedShield/WoodenBuckler/Toolbox 的
	# modulate 1/position 0,-3x/scale 0.3，不覆盖则锁图标显示基场景默认样式）。
	for key in data.get("lock_props", {}):
		var lock: Sprite2D = item.get_node("Lock")
		var lv = data.lock_props[key]
		lock.set(key, Color(lv[0], lv[1], lv[2], lv[3]) if lv is Array and lv.size() == 4 else Vector2(lv[0], lv[1]))
	# 物理体（硬接口，LifecycleAndText 会 get_node）：多边形（CollisionPolygon2D）
	# 或形状（CollisionShape2D：圆/胶囊/矩形，进树前建 shape 资源），按数据二选一。
	if data.has("collision_shape"):
		var cs_spec: Dictionary = data.collision_shape
		var shape: Shape2D = ClassDB.instantiate(str(cs_spec.type))
		for pk in cs_spec.params:
			var pv = cs_spec.params[pk]
			shape.set(pk, Vector2(pv[0], pv[1]) if pv is Array else float(pv))
		var body = CollisionShape2D.new()
		body.name = "CollisionShape2D"
		body.visible = false
		body.position = Vector2(cs_spec.position[0], cs_spec.position[1])
		if cs_spec.has("rotation"):
			body.rotation = float(cs_spec.rotation)
		body.shape = shape
		item.add_child(body)
	else:
		var body_poly = CollisionPolygon2D.new()
		body_poly.name = "CollisionPolygon2D"
		body_poly.visible = false
		body_poly.position = Vector2(data.body_collision.position[0], data.body_collision.position[1])
		body_poly.polygon = _poly(data.body_collision.polygon)
		if data.body_collision.has("modulate"):
			var bm = data.body_collision.modulate
			body_poly.modulate = Color(bm[0], bm[1], bm[2], bm[3])
		item.add_child(body_poly)
	# 额外节点（如 Rope 的 SpeedTimer、粒子槽位的 SpecificDragParticles）：
	# 按数据动态创建 + 接线，进树前就位，@onready 才接得到。
	# 这是「条件槽位」的核心：场景差异进数据，不进手写场景文件。
	# parent 支持挂 Icon 下（原版粒子就挂那，引擎两处都扫描收集）。
	for spec in data.get("extra_nodes", []):
		var node: Node
		if str(spec.get("scene", "")) != "":
			# 整场景实例（如 SkillLight.tscn）：子树由原场景自带。
			var packed = await AssetStream.request_resource(str(spec.scene), scope)
			node = packed.instantiate()
		else:
			node = ClassDB.instantiate(str(spec.type))
		node.name = str(spec.name)
		for group in spec.get("groups", []):
			node.add_to_group(str(group))
		for key in spec.get("props", {}):
			node.set(key, await _decode(spec.props[key], scope))
		if str(spec.get("script", "")) != "":
			node.set_script(load(str(spec.script)))
		for conn in spec.get("connections", []):
			node.connect(str(conn.signal), Callable(item, str(conn.method)))
		var parent: Node = item if str(spec.get("parent", ".")) == "." else item.get_node(str(spec.parent))
		parent.add_child(node)
	return true

## 额外节点属性值的类型还原：{"color":[r,g,b,a]}→Color，{"vec2":[x,y]}→Vector2，
## {"res":"res://..."}→资源（走 AssetStream 限域加载），其余原样返回。
static func _decode(value, scope: String):
	if value is Dictionary:
		if value.has("color"):
			return Color(value.color[0], value.color[1], value.color[2], value.color[3])
		if value.has("vec2"):
			return Vector2(value.vec2[0], value.vec2[1])
		if value.has("res"):
			return await AssetStream.request_resource(str(value.res), scope)
	return value

static func _poly(flat: Array) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(0, flat.size(), 2):
		points.append(Vector2(flat[i], flat[i + 1]))
	return points
