extends Node
## 开发者模式 · 物品模板试点验收（正常游戏不进入，只能显式运行本场景）。
## 遍历 asset_bindings.json 里带 template 标记的绑定，走新链路实例化（新基场景+数据覆盖），
## 在进树前断言覆盖数据逐字段生效，进树后断言 _ready 完整跑完且背包占格与数据一致。
## 失败非零退出；JSON 报告写到 --qa-output 目录。

var output := ""
var checks: Array = []
var failures: Array = []

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run_tests")

func check(value, message: String):
	checks.append({"ok": bool(value), "message": message})
	if not value: failures.append(message)

func run_tests():
	while not Expedition.initialized: await get_tree().process_frame
	if output.is_empty(): output = "user://item_template_qa"
	DirAccess.make_dir_recursive_absolute(output)
	var holder = Node2D.new()
	holder.hide()
	Game.mainNode.add_child(holder)
	var bindings: Dictionary = Expedition.bindings.bindings
	var template_ids: Array = []
	for id in bindings:
		if str(bindings[id].get("template", "")) != "": template_ids.append(str(id))
	check(template_ids.size() > 0, "asset_bindings.json has template bindings")
	for id in template_ids:
		await _check_template_item(id, holder)
	check(Expedition.bindings.errors.is_empty(), "no native asset-binding errors: " + str(Expedition.bindings.errors))
	var report = {
		"ok": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"template_ids": template_ids,
	}
	var file = FileAccess.open(output.path_join("item-template-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ITEM_TEMPLATE_QA ok=", report.ok, " failures=", failures.size())
	Game._begin_shutdown()
	await AssetStream.drain()
	get_tree().call_deferred("quit", 0 if failures.is_empty() else 1)

func _check_template_item(id: String, holder: Node2D) -> void:
	var data: Dictionary = ItemTemplate.override_for(id)
	check(not data.is_empty(), id + ": override data present")
	if data.is_empty(): return
	var paths = ItemTemplate.preload_paths(id)
	check(await AssetStream.prepare(paths, "item-template-qa"), id + ": template dependencies load")
	var item = await Expedition.bindings.instance_async(id, Item.Owner.BuildViewerIcon, "item-template-qa")
	check(is_instance_valid(item), id + ": template item instantiates")
	if not is_instance_valid(item):
		AssetStream.release("item-template-qa")
		return
	# --- 进树前：覆盖数据必须逐字段生效（此刻 _ready 未跑，纯数据断言）---
	check(str(item.name) == str(data.root_name), id + ": root name matches")
	check(str(item.get_script().resource_path) == str(data.script), id + ": item script matches")
	var body_node_name := "CollisionShape2D" if data.has("collision_shape") else "CollisionPolygon2D"
	for node_path in ["CollisionMap", "Icon", "Icon/Sockets", "ClickArea", "ClickArea/CollisionPolygon2D", "BottomCenter", "AnimationPlayer", "DragParticles", "Lock", body_node_name]:
		check(item.has_node(node_path), id + ": interface node present " + node_path)
	var icon: Sprite2D = item.get_node("Icon")
	check(icon.texture != null and str(icon.texture.resource_path) == str(data.icon.texture), id + ": icon texture matches")
	check(icon.scale.is_equal_approx(Vector2(data.icon.scale[0], data.icon.scale[1])), id + ": icon scale matches")
	check(icon.position.is_equal_approx(Vector2(data.icon.position[0], data.icon.position[1])), id + ": icon position matches")
	var mat = data.icon.get("material")
	if mat is Dictionary:
		check(icon.material is ShaderMaterial, id + ": icon dissolve material applied")
	else:
		check(icon.material == preload("res://Shader/Item.material"), id + ": icon base material retained")
	var pm = item.physics_material_override
	check(pm != null and is_equal_approx(float(pm.friction), float(data.physics.friction)) and is_equal_approx(float(pm.bounce), float(data.physics.bounce)), id + ": physics material matches")
	var map: TileMap = item.get_node("CollisionMap")
	check(map.position.is_equal_approx(Vector2(data.collision_map.position[0], data.collision_map.position[1])), id + ": collision map position matches")
	var expected_cells := {}
	var tile_ids := {}
	for cell in data.collision_map.cells:
		expected_cells[Vector2i(cell[0], cell[1])] = int(cell[2])
		tile_ids[int(cell[2])] = true
	var actual_cells := {}
	for tile_id in tile_ids:
		for cell in map.get_used_cells_by_id(0, tile_id):
			actual_cells[cell] = tile_id
	check(actual_cells == expected_cells, id + ": collision map cells match (" + str(actual_cells) + " vs " + str(expected_cells) + ")")
	check(item.get_node("BottomCenter").position.is_equal_approx(Vector2(data.bottom_center[0], data.bottom_center[1])), id + ": bottom center matches")
	# --- 物理体二选一：多边形（CollisionPolygon2D）或形状（CollisionShape2D：圆/胶囊/矩形）---
	if data.has("collision_shape"):
		var cs_spec: Dictionary = data.collision_shape
		var body_shape = item.get_node_or_null("CollisionShape2D")
		check(body_shape != null and not body_shape.visible, id + ": body collision shape present and hidden")
		if body_shape is CollisionShape2D:
			var s = body_shape.shape
			check(str(s.get_class()) == "RectangleShape2D" or s is Shape2D, id + ": body shape is Shape2D")
			check(s != null and s.get_class() == str(cs_spec.type), id + ": body shape type matches (" + (str(s.get_class()) if s != null else "null") + ")")
			for pk in cs_spec.params:
				var expect = cs_spec.params[pk]
				var gotv = s.get(pk)
				if expect is Array:
					check(gotv is Vector2 and (gotv as Vector2).is_equal_approx(Vector2(expect[0], expect[1])), id + ": body shape param " + pk + " matches")
				else:
					check(is_equal_approx(float(gotv), float(expect)), id + ": body shape param " + pk + " matches")
			check(body_shape.position.is_equal_approx(Vector2(cs_spec.position[0], cs_spec.position[1])), id + ": body shape position matches")
			if cs_spec.has("rotation"):
				check(is_equal_approx(body_shape.rotation, float(cs_spec.rotation)), id + ": body shape rotation matches")
	else:
		var body = item.get_node_or_null("CollisionPolygon2D")
		check(body != null and not body.visible, id + ": body collision polygon present and hidden")
		if body is CollisionPolygon2D:
			check(body.polygon.size() * 2 == data.body_collision.polygon.size() and _poly_equal(body.polygon, data.body_collision.polygon), id + ": body collision polygon matches")
	var click_poly: PackedVector2Array = item.get_node("ClickArea/CollisionPolygon2D").polygon
	check(click_poly.size() * 2 == data.click_polygon.size() and _poly_equal(click_poly, data.click_polygon), id + ": click polygon matches")
	if data.has("click_position"):
		check(item.get_node("ClickArea/CollisionPolygon2D").position.is_equal_approx(Vector2(data.click_position[0], data.click_position[1])), id + ": click polygon position matches")
	check(item.get_node("Icon/Sockets").scale.is_equal_approx(Vector2(data.sockets_scale[0], data.sockets_scale[1])), id + ": sockets scale matches")
	# --- 条件槽位·宝石孔：孔位数量/名字/坐标/场景来源，进树前逐项对照数据 ---
	var socket_specs: Array = data.get("gem_sockets", [])
	check(item.get_node("Icon/Sockets").get_child_count() == socket_specs.size(), id + ": gem socket count matches (" + str(item.get_node("Icon/Sockets").get_child_count()) + "/" + str(socket_specs.size()) + ")")
	for spec in socket_specs:
		var socket_path := "Icon/Sockets/" + str(spec.name)
		check(item.has_node(socket_path), id + ": gem socket present " + socket_path)
		if item.has_node(socket_path):
			var socket = item.get_node(socket_path)
			check(socket.position.is_equal_approx(Vector2(spec.position[0], spec.position[1])), id + ": gem socket position matches " + socket_path)
			check(str(socket.scene_file_path) == ItemTemplate.GEM_SOCKET_SCENE, id + ": gem socket scene matches " + socket_path)
	var collision_cells := {}
	for cell in data.collision_map.cells:
		if int(cell[2]) == 3: collision_cells[Vector2(cell[0], cell[1])] = true
	# --- 额外节点（Rope 的 SpeedTimer、粒子槽位的 SpecificDragParticles）：
	#     存在 + 挂载位置 + 类名 + 脚本 + 属性 + 信号接线 ---
	var particle_count := 0
	for spec in data.get("extra_nodes", []):
		var p := str(spec.name) if str(spec.get("parent", ".")) == "." else str(spec.parent) + "/" + str(spec.name)
		if str(spec.name).begins_with("SpecificDragParticles"): particle_count += 1
		check(item.has_node(p), id + ": extra node present " + p)
		if item.has_node(p):
			var n = item.get_node(p)
			if str(spec.get("scene", "")) != "":
				check(str(n.scene_file_path) == str(spec.scene), id + ": extra scene instance matches " + p)
			else:
				check(str(n.get_class()) == str(spec.type), id + ": extra node class matches " + p)
			if str(spec.get("script", "")) != "":
				check(str(n.get_script().resource_path) == str(spec.script), id + ": extra node script matches " + p)
			for key in spec.get("props", {}):
				check(_prop_matches(n.get(key), spec.props[key]), id + ": extra node prop matches " + p + "." + str(key))
			for conn in spec.get("connections", []):
				check(n.is_connected(str(conn.signal), Callable(item, str(conn.method))), id + ": extra node connection wired " + p)
	# --- 基场景结构性接口（如宝石的 SocketDetectionArea / GemAnimation）：模板选型必须带齐 ---
	for node_path in data.get("interface_nodes", []):
		check(item.has_node(str(node_path)), id + ": template interface node present " + str(node_path))
	for player_path in data.get("required_animations", {}):
		if item.has_node(str(player_path)):
			for anim_name in data.required_animations[player_path]:
				check(item.get_node(str(player_path)).has_animation(str(anim_name)), id + ": template animation present " + str(player_path) + "/" + str(anim_name))
	# --- 进树：_ready 必须完整跑完（接口齐备 + 背包占格生效）---
	holder.add_child(item)
	await get_tree().process_frame
	check(is_instance_valid(item) and item.sprite.texture != null, id + ": survives _ready with visible texture")
	if is_instance_valid(item):
		var placed_cells := {}
		for cell in item.collisionCells: placed_cells[Vector2(cell.x, cell.y)] = true
		check(placed_cells == collision_cells, id + ": inventory collision cells match data (" + str(placed_cells.keys()) + " vs " + str(collision_cells.keys()) + ")")
		# 条件槽位·粒子：进树后引擎必须把 SpecificDragParticles 收进拖拽系统（LifecycleAndText 收集）
		if particle_count > 0:
			check(item.specificDragParticles.size() >= particle_count, id + ": drag particle slot collected by runtime (" + str(item.specificDragParticles.size()) + "/" + str(particle_count) + ")")
		# 条件槽位·宝石孔：进树后 Item.gd 的 @onready sockets 必须收到全部孔位
		if not socket_specs.is_empty():
			check(item.sockets.size() == socket_specs.size(), id + ": gem sockets collected by runtime (" + str(item.sockets.size()) + "/" + str(socket_specs.size()) + ")")
		item.free()
	AssetStream.release("item-template-qa")
	AssetStream.release("popup")

func _poly_equal(actual: PackedVector2Array, flat: Array) -> bool:
	for i in flat.size() / 2:
		if not actual[i].is_equal_approx(Vector2(flat[i * 2], flat[i * 2 + 1])): return false
	return true

## 额外节点属性比对：{"res":...} 比资源路径，{"color":...}/{"vec2":...} 比数值（近似相等），其余直接 ==
func _prop_matches(actual, expected) -> bool:
	if expected is Dictionary:
		if expected.has("res"):
			return actual != null and str(actual.resource_path) == str(expected.res)
		if expected.has("color"):
			var c := Color(expected.color[0], expected.color[1], expected.color[2], expected.color[3])
			return actual is Color and is_equal_approx(actual.r, c.r) and is_equal_approx(actual.g, c.g) \
				and is_equal_approx(actual.b, c.b) and is_equal_approx(actual.a, c.a)
		if expected.has("vec2"):
			var v := Vector2(expected.vec2[0], expected.vec2[1])
			return actual is Vector2 and actual.is_equal_approx(v)
	return actual == expected or (actual is float and expected is float and is_equal_approx(actual, expected))
